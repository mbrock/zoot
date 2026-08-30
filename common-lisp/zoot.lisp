(defpackage #:zoot
  (:use #:cl)
  (:shadow #:concatenate)
  (:export
   #:text #:+newline+ #:concatenate #:cat #:vcat #:choice #:nest #:align
   #:flatten #:group
   #:make-f1 #:make-f2 #:pick #:render #:format-document
   #:*cost-measure* #:linear-overflow-cost #:squared-overflow-cost
   #:result-candidate #:result-frontier #:result-statistics #:result-tainted-p
   #:candidate-last #:candidate-rank
   #:rank-overflow #:rank-height
   #:statistics-evaluations #:statistics-memo-hits
   #:statistics-memo-entries #:statistics-frontier-maximum
   #:statistics-frontier-histogram
   #:statistics-taints-deferred #:statistics-taints-forced))

(in-package #:zoot)

(deftype nonnegative-fixnum ()
  '(integer 0 #.most-positive-fixnum))

;;; Documents
;;;
;;; Documents are plain data, as in recursive.zig: a string is a text
;;; terminal, the newline character is a hard line break, a cons is a
;;; concatenation, and small structs cover choice, indentation, and memo
;;; checkpoints.

(defconstant +initial-memo-weight+ 6
  "Number of concatenation levels between memo checkpoints, as in the OCaml
reference implementation (its PARAM_MEMO_LIMIT is 7, with initial weight 6).")

(defstruct (choice-document (:constructor %choice-document (left right)))
  (left nil :read-only t)
  (right nil :read-only t))

(defstruct (nest-document (:constructor %nest-document (amount child)))
  (amount 0 :type nonnegative-fixnum :read-only t)
  (child nil :read-only t))

(defstruct (align-document (:constructor %align-document (child)))
  (child nil :read-only t))

(defstruct (memo-document (:constructor %memo-document (child)))
  ;; Each checkpoint owns its context table for the document's lifetime.
  ;; Entries are keyed by evaluation context under one cost configuration,
  ;; so a document belongs to the configuration it is first picked with.
  (contexts (make-hash-table :test #'eq) :type hash-table :read-only t)
  (child nil :read-only t))

(deftype document ()
  '(or string character cons
       choice-document nest-document align-document memo-document))

(defun memo-weight (document)
  "Structural levels below DOCUMENT until a memo checkpoint. Zero marks a
checkpoint. The countdown flows through every composite node, choices
included, so that documents sharing subtrees through choice chains still
hit checkpoints; leaves reset it. The public constructors wrap any node
whose countdown runs out, which also bounds this recursion."
  (typecase document
    (memo-document 0)
    (cons (min (next-memo-weight (car document))
               (next-memo-weight (cdr document))))
    (choice-document
     (min (next-memo-weight (choice-document-left document))
          (next-memo-weight (choice-document-right document))))
    (nest-document (next-memo-weight (nest-document-child document)))
    (align-document (next-memo-weight (align-document-child document)))
    (t +initial-memo-weight+)))

(defun next-memo-weight (document)
  (let ((weight (memo-weight document)))
    (if (zerop weight) +initial-memo-weight+ (1- weight))))

(defun checkpointed (node)
  "Wrap NODE in a memo checkpoint when its countdown has run out."
  (if (zerop (memo-weight node))
      (%memo-document node)
      node))

(defun text (string)
  "A terminal document. STRING must not contain a newline."
  (check-type string string)
  (when (find #\Newline string)
    (error "TEXT terminals cannot contain newlines: ~S" string))
  string)

(defconstant +newline+ #\Newline
  "A hard newline. Its following indentation is determined by NEST and ALIGN.")

(defun concatenate (left right)
  "Unaligned concatenation: place RIGHT immediately after LEFT."
  (checkpointed (cons left right)))

(defun choice (left right)
  "An arbitrary choice between two documents."
  (checkpointed (%choice-document left right)))

(defun nest (amount document)
  "Indent lines after the first by AMOUNT columns."
  (check-type amount nonnegative-fixnum)
  (if (zerop amount)
      document
      (checkpointed (%nest-document amount document))))

(defun align (document)
  "Use the current column as DOCUMENT's indentation base."
  (checkpointed (%align-document document)))

(defun cat (&rest documents)
  (reduce #'concatenate documents :initial-value (text "")))

(defun vcat (&rest documents)
  (if (null documents)
      (text "")
      (reduce (lambda (left right)
                (concatenate (concatenate left +newline+) right))
              (rest documents)
              :initial-value (first documents))))

(defun flatten (document)
  "Replace newlines with spaces and recursively flatten both choice
branches. Memo checkpoints are preserved in place, so the flattened
document needs no reweighting."
  (etypecase document
    (string document)
    (character " ")
    (cons (cons (flatten (car document)) (flatten (cdr document))))
    (memo-document (%memo-document (flatten (memo-document-child document))))
    (choice-document
     (%choice-document (flatten (choice-document-left document))
                       (flatten (choice-document-right document))))
    (nest-document (flatten (nest-document-child document)))
    (align-document
     (%align-document (flatten (align-document-child document))))))

(defun group (document)
  "Choose between DOCUMENT and its flattened form."
  (choice document (flatten document)))

;;; Costs and Pareto measures

(defvar *cost-measure* nil
  "When non-NIL, dynamically override a cost factory's text measure function.
The function receives PAGE-WIDTH, COLUMN, and TEXT-LENGTH and returns a
nonnegative integer. Newline count remains the secondary rank component.")

(declaim (type (or null function) *cost-measure*))

(defun linear-overflow-cost (page-width column length)
  "Additional linear overflow caused by placing LENGTH characters at COLUMN."
  (declare (type nonnegative-fixnum page-width column length))
  (the nonnegative-fixnum
       (max 0 (- (+ column length) (max page-width column)))))

(defun squared-overflow-cost (page-width column length)
  "Increase in squared line overflow caused by a text placement."
  (declare (type nonnegative-fixnum page-width column length))
  (let* ((old-overflow (max 0 (- column page-width)))
         (new-text-overflow
           (max 0 (- (+ column length) (max page-width column)))))
    (the nonnegative-fixnum
         (* new-text-overflow (+ (* 2 old-overflow) new-text-overflow)))))

(defstruct (cost (:constructor %cost (measure width limit)))
  (measure #'squared-overflow-cost :type function :read-only t)
  (width 80 :type nonnegative-fixnum :read-only t)
  (limit 96 :type nonnegative-fixnum :read-only t))

(defun default-computation-width (page-width)
  (declare (type nonnegative-fixnum page-width))
  (the nonnegative-fixnum (+ page-width (floor page-width 5))))

(defun make-f1 (page-width &key computation-width)
  "Minimize linear overflow, then newline count (paper Example 3.4)."
  (%cost #'linear-overflow-cost page-width
         (or computation-width (default-computation-width page-width))))

(defun make-f2 (page-width &key computation-width)
  "Minimize squared overflow, then newline count (paper Example 3.5)."
  (%cost #'squared-overflow-cost page-width
         (or computation-width (default-computation-width page-width))))

(defstruct (rank (:constructor %rank (&optional (overflow 0) (height 0))))
  (overflow 0 :type nonnegative-fixnum :read-only t)
  (height 0 :type nonnegative-fixnum :read-only t))

(defun text-overflow (cost column length)
  (declare (type nonnegative-fixnum column length))
  ;; VALUES truncates the measure's result to one value, so the type
  ;; assertion compiles to an inline fixnum test instead of a full
  ;; multiple-values check.
  (the nonnegative-fixnum
       (values (funcall (the function *cost-measure*)
                        (cost-width cost) column length))))

;;; Candidates carry their rank components as raw slots so that combining
;;; and comparing candidates never allocates intermediate RANK objects.
;;; Inlining the constructor lets callers with already-derived slot types
;;; allocate directly without re-checking them.
(declaim (inline %candidate))
(defstruct (candidate (:constructor %candidate (layout last overflow height)))
  (layout nil :type document :read-only t)
  (last 0 :type nonnegative-fixnum :read-only t)
  (overflow 0 :type nonnegative-fixnum :read-only t)
  (height 0 :type nonnegative-fixnum :read-only t))

(defun candidate-rank (candidate)
  "The candidate's (overflow, height) rank as a fresh RANK object."
  (%rank (candidate-overflow candidate) (candidate-height candidate)))

(declaim (inline better-rank-p))
(defun better-rank-p (left right)
  "Strict lexicographic (overflow, height) order between candidates."
  (declare (type candidate left right))
  (or (< (candidate-overflow left) (candidate-overflow right))
      (and (= (candidate-overflow left) (candidate-overflow right))
           (< (candidate-height left) (candidate-height right)))))

(defstruct (duel (:constructor %duel (first second)))
  "The common two-point Pareto frontier, ordered by decreasing final column."
  (first nil :type candidate :read-only t)
  (second nil :type candidate :read-only t))

(defstruct statistics
  (evaluations 0 :type nonnegative-fixnum)
  (memo-hits 0 :type nonnegative-fixnum)
  (memo-entries 0 :type nonnegative-fixnum)
  (taints-deferred 0 :type nonnegative-fixnum)
  (taints-forced 0 :type nonnegative-fixnum)
  (frontier-maximum 0 :type nonnegative-fixnum)
  (frontier-histogram (make-hash-table) :type hash-table))

(defvar *cost* (make-f2 80) "Cost configuration dynamically bound by PICK.")
(defvar *statistics* (make-statistics)
  "Statistics dynamically accumulated by PICK.")

(declaim (type cost *cost*)
         (type statistics *statistics*))

#+sbcl
(declaim (sb-ext:always-bound *cost* *cost-measure* *statistics*))

(defmacro note-statistic (place)
  #+zoot-statistics `(incf ,place)
  #-zoot-statistics (declare (ignore place))
  #-zoot-statistics nil)

#-zoot-statistics
(defmacro note-evaluation (evaluation)
  evaluation)

(declaim (inline dominates-p))
(defun dominates-p (left right)
  (declare (type candidate left right))
  (and (<= (candidate-last left) (candidate-last right))
       (or (< (candidate-overflow left) (candidate-overflow right))
           (and (= (candidate-overflow left) (candidate-overflow right))
                (<= (candidate-height left) (candidate-height right))))))

(defstruct (tainted-context (:constructor nil)))

(defstruct (tainted-document-context
            (:include tainted-context)
            (:constructor %tainted-document-context (document last base)))
  (document nil :type document :read-only t)
  (last 0 :type nonnegative-fixnum :read-only t)
  (base 0 :type nonnegative-fixnum :read-only t))

(defstruct (tainted-wrap-context
            (:include tainted-context)
            (:constructor %tainted-wrap-context (kind amount evaluation)))
  (kind :nest :type (member :nest :align) :read-only t)
  (amount 0 :type nonnegative-fixnum :read-only t)
  (evaluation nil :type t :read-only t))

(defstruct (tainted-right-context
            (:include tainted-context)
            (:constructor %tainted-right-context (left evaluation)))
  (left nil :type candidate :read-only t)
  (evaluation nil :type t :read-only t))

(defstruct (tainted-left-context
            (:include tainted-context)
            (:constructor %tainted-left-context (document base evaluation)))
  (document nil :type cons :read-only t)
  (base 0 :type nonnegative-fixnum :read-only t)
  (evaluation nil :type t :read-only t))

(deftype evaluation ()
  '(or null candidate duel simple-vector tainted-context))

;;; Frontier shapes
;;;
;;; A normal, non-empty evaluation is a Pareto frontier of one, two, or
;;; many candidates, ordered by strictly decreasing final column and so
;;; by strictly increasing rank. These helpers treat the three
;;; representations uniformly.

(declaim (inline frontier-length frontier-ref))

(defun frontier-length (frontier)
  (etypecase frontier
    (candidate 1)
    (duel 2)
    (simple-vector (length frontier))))

(defun frontier-ref (frontier index)
  (declare (type nonnegative-fixnum index))
  (etypecase frontier
    (candidate frontier)
    (duel (if (zerop index) (duel-first frontier) (duel-second frontier)))
    (simple-vector (svref frontier index))))

(defmacro map-frontier ((candidate frontier) &body body)
  "Rebuild FRONTIER, replacing each CANDIDATE with the value of BODY.
Purely syntactic so that no closure is ever allocated."
  (let ((shape (gensym "FRONTIER"))
        (index (gensym "INDEX"))
        (result (gensym "RESULT")))
    `(let ((,shape ,frontier))
       (flet ((transform (,candidate) ,@body))
         (declare (inline transform))
         (etypecase ,shape
           (candidate (transform ,shape))
           (duel (%duel (transform (duel-first ,shape))
                        (transform (duel-second ,shape))))
           (simple-vector
            (let ((,result (make-array (length ,shape))))
              (dotimes (,index (length ,shape) ,result)
                (setf (svref ,result ,index)
                      (transform (svref ,shape ,index)))))))))))

(defmacro do-frontier ((candidate frontier) &body body)
  "Execute BODY for each CANDIDATE, in decreasing final column order."
  (let ((shape (gensym "FRONTIER")) (index (gensym "INDEX")))
    `(let ((,shape ,frontier))
       (etypecase ,shape
         (candidate (let ((,candidate ,shape)) ,@body))
         (duel (let ((,candidate (duel-first ,shape))) ,@body)
               (let ((,candidate (duel-second ,shape))) ,@body))
         (simple-vector
          (dotimes (,index (length ,shape))
            (let ((,candidate (svref ,shape ,index))) ,@body)))))))

(defun finalize-frontier (buffer count)
  "Pack COUNT ordered candidates from BUFFER into the smallest shape."
  (declare (type simple-vector buffer) (type nonnegative-fixnum count))
  (case count
    (1 (svref buffer 0))
    (2 (%duel (svref buffer 0) (svref buffer 1)))
    (t (subseq buffer 0 count))))

(defun tainted-evaluation (context)
  (declare (type tainted-context context))
  (note-statistic
   (statistics-taints-deferred (the statistics *statistics*)))
  context)

(defun force-evaluation (evaluation)
  (etypecase evaluation
    (candidate evaluation)
    (duel (duel-first evaluation))
    (vector (aref evaluation 0))
    (null (error "Cannot choose from an empty frontier"))
    (tainted-context
     (note-statistic
      (statistics-taints-forced (the statistics *statistics*)))
     (etypecase evaluation
       (tainted-document-context
        (force-evaluation
         (note-evaluation
          (evaluate-document
           (tainted-document-context-document evaluation)
           (tainted-document-context-last evaluation)
           (tainted-document-context-base evaluation)))))
       (tainted-wrap-context
        (wrap-candidate
         (tainted-wrap-context-kind evaluation)
         (tainted-wrap-context-amount evaluation)
         (force-evaluation (tainted-wrap-context-evaluation evaluation))))
       (tainted-right-context
        (concatenate-candidates
         (tainted-right-context-left evaluation)
         (force-evaluation (tainted-right-context-evaluation evaluation))))
       (tainted-left-context
        (let* ((left (force-evaluation
                      (tainted-left-context-evaluation evaluation)))
               (right (concatenate-right
                       (tainted-left-context-document evaluation) left
                       (tainted-left-context-base evaluation))))
          (force-evaluation right)))))))

(defun merge-frontiers (left right)
  "The ordered Pareto merge from Pretty Expressive: walk both frontiers
in decreasing final column order, dropping dominated candidates. Linear,
because a candidate that survives the other side's head cannot be
dominated by anything behind that head."
  (let* ((left-length (frontier-length left))
         (right-length (frontier-length right))
         (total (+ left-length right-length))
         (small (make-array 8))
         (buffer (if (<= total 8) small (make-array total)))
         (count 0)
         (i 0)
         (j 0))
    (declare (dynamic-extent small)
             (type nonnegative-fixnum count i j))
    (flet ((emit (candidate)
             (setf (svref buffer count) candidate)
             (incf count)))
      (loop while (and (< i left-length) (< j right-length))
            do (let ((a (frontier-ref left i))
                     (b (frontier-ref right j)))
                 ;; On equal points the left candidate is retained,
                 ;; matching ordered incremental insertion.
                 (cond ((dominates-p a b) (incf j))
                       ((dominates-p b a) (incf i))
                       ((> (candidate-last a) (candidate-last b))
                        (emit a) (incf i))
                       (t (emit b) (incf j)))))
      (loop while (< i left-length)
            do (emit (frontier-ref left i)) (incf i))
      (loop while (< j right-length)
            do (emit (frontier-ref right j)) (incf j)))
    (finalize-frontier buffer count)))

(defun merge-evaluations (left right)
  "Merge like Pretty Expressive's measure sets: a normal frontier always
wins over taint, since taint means that computation has left the bounded
region. If both sides are tainted, retain the left promise."
  (declare (type evaluation left right))
  (cond ((null left) right)
        ((null right) left)
        ((tainted-context-p left)
         (if (tainted-context-p right) left right))
        ((tainted-context-p right) left)
        ;; Two singletons are the overwhelmingly common case; settle
        ;; them without the merge buffer.
        ((and (candidate-p left) (candidate-p right))
         (cond ((dominates-p left right) left)
               ((dominates-p right left) right)
               ((> (candidate-last left) (candidate-last right))
                (%duel left right))
               (t (%duel right left))))
        (t (merge-frontiers left right))))

;;; Recursive evaluator

#+zoot-statistics
(defun note-frontier (frontier)
  (declare (type (vector t) frontier))
  (let* ((statistics (the statistics *statistics*))
         (length (length frontier))
         (histogram (statistics-frontier-histogram statistics)))
    (setf (statistics-frontier-maximum statistics)
          (max length (statistics-frontier-maximum statistics)))
    (setf (gethash length histogram)
          (the nonnegative-fixnum
               (1+ (the nonnegative-fixnum
                         (gethash length histogram 0))))))
  frontier)

#+zoot-statistics
(defgeneric note-evaluation (evaluation))

#+zoot-statistics
(defmethod note-evaluation ((evaluation null))
  (let* ((statistics (the statistics *statistics*))
         (histogram (statistics-frontier-histogram statistics)))
    (setf (gethash 0 histogram)
          (the nonnegative-fixnum
               (1+ (the nonnegative-fixnum (gethash 0 histogram 0))))))
  evaluation)

#+zoot-statistics
(defmethod note-evaluation ((evaluation vector))
  (note-frontier evaluation))

#+zoot-statistics
(defmethod note-evaluation ((evaluation candidate))
  (let* ((statistics (the statistics *statistics*))
         (histogram (statistics-frontier-histogram statistics)))
    (setf (statistics-frontier-maximum statistics)
          (max 1 (statistics-frontier-maximum statistics)))
    (setf (gethash 1 histogram)
          (the nonnegative-fixnum
               (1+ (the nonnegative-fixnum (gethash 1 histogram 0))))))
  evaluation)

#+zoot-statistics
(defmethod note-evaluation ((evaluation duel))
  (let* ((statistics (the statistics *statistics*))
         (histogram (statistics-frontier-histogram statistics)))
    (setf (statistics-frontier-maximum statistics)
          (max 2 (statistics-frontier-maximum statistics)))
    (setf (gethash 2 histogram)
          (the nonnegative-fixnum
               (1+ (the nonnegative-fixnum (gethash 2 histogram 0))))))
  evaluation)

#+zoot-statistics
(defmethod note-evaluation ((evaluation tainted-context))
  evaluation)

(declaim (inline memo-context-key))
(defun memo-context-key (last base limit)
  ;; LAST and BASE are both at most LIMIT here, so this is a collision-free
  ;; row-major encoding of the pair, as in the OCaml implementation.
  (declare (type nonnegative-fixnum last base limit))
  (the nonnegative-fixnum
       (+ last
          (the nonnegative-fixnum
               (* base (the nonnegative-fixnum (1+ limit)))))))

(declaim (inline exceeds-computation-limit-p))
(defun exceeds-computation-limit-p (document last base)
  (declare (type nonnegative-fixnum last base))
  (let ((limit (cost-limit (the cost *cost*))))
    (or (> base limit)
        (> (if (stringp document)
               (+ last (length document))
               last)
           limit))))

(defun evaluate-document (document last base)
  "Evaluate one document node after memo and taint checks. The ETYPECASE
is the document type check; the argument is deliberately undeclared so
call sites do not re-check child slots on every traversal."
  (declare (type nonnegative-fixnum last base))
  (etypecase document
    (cons
     (evaluate-concatenation document last base))
    (string
     (let ((length (length document)))
       (%candidate document
                   (the nonnegative-fixnum (+ last length))
                   (text-overflow (the cost *cost*) last length)
                   0)))
    (choice-document
     (merge-evaluations
      (evaluate (choice-document-left document) last base)
      (evaluate (choice-document-right document) last base)))
    (character
     (%candidate document base 0 1))
    (align-document
     (wrap-evaluation
      :align 0
      (evaluate (align-document-child document) last last)))
    (nest-document
     (let ((amount (nest-document-amount document)))
       (wrap-evaluation
        :nest amount
        (evaluate (nest-document-child document) last
                  (the nonnegative-fixnum (+ base amount))))))
    (memo-document
     (evaluate (memo-document-child document) last base))))

(defun evaluate (document last base)
  (declare (type nonnegative-fixnum last base))
  (if (memo-document-p document)
      (let ((limit (cost-limit *cost*)))
        (if (and (<= last limit) (<= base limit))
            (let ((contexts (memo-document-contexts document))
                  (key (memo-context-key last base limit)))
              (multiple-value-bind (value present)
                  (gethash key contexts)
                (if present
                    (progn
                      (note-statistic
                       (statistics-memo-hits *statistics*))
                      value)
                    (let ((value (evaluate (memo-document-child document)
                                           last base)))
                      (setf (gethash key contexts) value)
                      (note-statistic
                       (statistics-memo-entries *statistics*))
                      value))))
            (evaluate (memo-document-child document) last base)))
      (progn
        (note-statistic
         (statistics-evaluations (the statistics *statistics*)))
        (if (exceeds-computation-limit-p document last base)
            (tainted-evaluation
             (%tainted-document-context document last base))
            (note-evaluation (evaluate-document document last base))))))

;;; Layout reconstruction. Chosen layouts are choice-free trees of conses,
;;; strings, newline characters, and wrap structs, built without memo
;;; checkpoints since they are only rendered.

(defun wrap-candidate (kind amount candidate)
  (%candidate
   (ecase kind
     (:nest (%nest-document amount (candidate-layout candidate)))
     (:align (%align-document (candidate-layout candidate))))
   (candidate-last candidate)
   (candidate-overflow candidate)
   (candidate-height candidate)))

(defun wrap-evaluation (kind amount evaluation)
  (etypecase evaluation
    (null evaluation)
    (tainted-context
     (tainted-evaluation
      (%tainted-wrap-context kind amount evaluation)))
    ((or candidate duel simple-vector)
     (map-frontier (candidate evaluation)
       (wrap-candidate kind amount candidate)))))

(defun concatenate-candidates (left right)
  (declare (type candidate left right))
  (%candidate
   (cons (candidate-layout left) (candidate-layout right))
   (candidate-last right)
   (the nonnegative-fixnum
        (+ (candidate-overflow left) (candidate-overflow right)))
   (the nonnegative-fixnum
        (+ (candidate-height left) (candidate-height right)))))

(defun concatenate-right-evaluation (left right)
  (declare (type candidate left))
  (etypecase right
    (null right)
    (tainted-context
     (tainted-evaluation
      (%tainted-right-context left right)))
    ;; Adding the same left rank preserves right-side dominance and ordering.
    ((or candidate duel simple-vector)
     (map-frontier (candidate right)
       (concatenate-candidates left candidate)))))

(defun concatenate-right (document left base)
  (declare (type cons document))
  (concatenate-right-evaluation
   left
   (evaluate (cdr document) (candidate-last left) base)))

(defun concatenate-left-evaluation (document base left)
  (declare (type cons document)
           (type nonnegative-fixnum base))
  (etypecase left
    (null left)
    (tainted-context
     (tainted-evaluation
      (%tainted-left-context document base left)))
    (candidate (concatenate-right document left base))
    ((or duel simple-vector)
     (let ((result nil))
       (do-frontier (candidate left)
         (setf result
               (merge-evaluations
                result
                (concatenate-right document candidate base))))
       result))))

(defun evaluate-concatenation (document last base)
  (declare (type cons document)
           (type nonnegative-fixnum last base))
  (concatenate-left-evaluation
   document base
   (evaluate (car document) last base)))

(defstruct (result (:constructor %result
                       (candidate frontier statistics tainted-p)))
  (candidate nil :type candidate :read-only t)
  (frontier #() :type vector :read-only t)
  (statistics (make-statistics) :type statistics :read-only t)
  (tainted-p nil :type boolean :read-only t))

(defun pick (document cost)
  "Resolve DOCUMENT with computation-width taint. Memo checkpoints cache
candidates as long as the document lives, so a document belongs to the
cost configuration it is first picked with. Ordinary Pareto frontiers
are exact and unrestricted; forced tainted regions deliberately recover
one candidate, as in Pretty Expressive and recursive.zig."
  (let ((*cost* cost)
        #+zoot-statistics
        (*statistics* (make-statistics))
        (*cost-measure* (or *cost-measure* (cost-measure cost))))
    (let* ((evaluation (evaluate document 0 0))
           (tainted-p (tainted-context-p evaluation))
           (frontier
             (the (vector t)
                  (etypecase evaluation
                    (null #())
                    (tainted-context
                     (vector (force-evaluation evaluation)))
                    (candidate (vector evaluation))
                    (duel (vector (duel-first evaluation)
                                  (duel-second evaluation)))
                    (vector (the (vector t) evaluation)))))
           (statistics *statistics*))
      (when (zerop (length frontier))
        (error "Document has no layouts"))
      (let ((best (aref frontier 0)))
        (loop for candidate across frontier
              when (better-rank-p candidate best)
                do (setf best candidate))
        (%result best frontier statistics tainted-p)))))

;;; Rendering

(defun render-layout (document stream last base)
  (declare (type nonnegative-fixnum last base))
  (etypecase document
    (string
     (write-string document stream)
     (the nonnegative-fixnum (+ last (length document))))
    (character
     (terpri stream)
     (loop repeat base do (write-char #\Space stream))
     base)
    (cons
     (render-layout (cdr document) stream
                    (render-layout (car document) stream last base)
                    base))
    (nest-document
     (render-layout (nest-document-child document) stream last
                    (the nonnegative-fixnum
                         (+ base (nest-document-amount document)))))
    (align-document
     (render-layout (align-document-child document) stream last last))
    (memo-document
     (render-layout (memo-document-child document) stream last base))
    (choice-document
     (error "Cannot render an unresolved choice"))))

(defun render (candidate &optional stream)
  "Render CANDIDATE. Return a string when STREAM is omitted."
  (if stream
      (progn (render-layout (candidate-layout candidate) stream 0 0) nil)
      (with-output-to-string (output)
        (render-layout (candidate-layout candidate) output 0 0))))

(defun format-document (document cost)
  "Resolve and render DOCUMENT in one call."
  (render (result-candidate (pick document cost))))
