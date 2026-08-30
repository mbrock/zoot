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

(defconstant +initial-memo-weight+ 6
  "Number of structural levels between memo checkpoints, as in the OCaml
reference implementation (its PARAM_MEMO_LIMIT is 7, with initial weight 6).")

(defstruct (document (:constructor nil))
  (memo-weight +initial-memo-weight+
               :type (integer 0 6)
               :read-only t)
  ;; Documents are single-use search spaces. Memoized candidates live as long
  ;; as the document and are reclaimed with it after its one PICK.
  (memo-table nil :type (or null hash-table))
  (consumed-p nil :type boolean))

(defstruct (text-document
            (:include document)
            (:constructor %text-document (text)))
  (text "" :type string :read-only t))

(defstruct (newline-document
            (:include document)
            (:constructor %newline-document ())))

(defstruct (concatenation-document
            (:include document)
            (:constructor %concatenation-document (left right memo-weight)))
  (left nil :type document :read-only t)
  (right nil :type document :read-only t))

(defstruct (choice-document
            (:include document)
            (:constructor %choice-document (left right memo-weight)))
  (left nil :type document :read-only t)
  (right nil :type document :read-only t))

(defstruct (nest-document
            (:include document)
            (:constructor %nest-document (amount child memo-weight)))
  (amount 0 :type nonnegative-fixnum :read-only t)
  (child nil :type document :read-only t))

(defstruct (align-document
            (:include document)
            (:constructor %align-document (child memo-weight)))
  (child nil :type document :read-only t))

(defun next-memo-weight (document)
  (let ((weight (document-memo-weight document)))
    (if (zerop weight) +initial-memo-weight+ (1- weight))))

(defun text (string)
  "A terminal document. STRING must not contain a newline."
  (check-type string string)
  (when (find #\Newline string)
    (error "TEXT terminals cannot contain newlines: ~S" string))
  (%text-document string))

(defparameter +newline+ (%newline-document)
  "A hard newline. Its following indentation is determined by NEST and ALIGN.")

(defun concatenate (left right)
  "Unaligned concatenation: place RIGHT immediately after LEFT."
  (%concatenation-document
   left right
   (min (next-memo-weight left) (next-memo-weight right))))

(defun choice (left right)
  "An arbitrary choice between two documents."
  (%choice-document
   left right
   (min (next-memo-weight left) (next-memo-weight right))))

(defun nest (amount document)
  "Indent lines after the first by AMOUNT columns."
  (check-type amount nonnegative-fixnum)
  (if (zerop amount)
      document
      (%nest-document amount document (next-memo-weight document))))

(defun align (document)
  "Use the current column as DOCUMENT's indentation base."
  (%align-document document (next-memo-weight document)))

(defun cat (&rest documents)
  (reduce #'concatenate documents :initial-value (text "")))

(defun vcat (&rest documents)
  (if (null documents)
      (text "")
      (reduce (lambda (left right)
                (concatenate (concatenate left +newline+) right))
              (rest documents)
              :initial-value (first documents))))

(defgeneric flatten (document)
  (:documentation
   "Replace newlines with spaces and recursively flatten both choice branches."))

(defmethod flatten ((document text-document)) document)
(defmethod flatten ((document newline-document)) (text " "))
(defmethod flatten ((document concatenation-document))
  (concatenate (flatten (concatenation-document-left document))
               (flatten (concatenation-document-right document))))
(defmethod flatten ((document choice-document))
  (choice (flatten (choice-document-left document))
          (flatten (choice-document-right document))))
(defmethod flatten ((document nest-document))
  (flatten (nest-document-child document)))
(defmethod flatten ((document align-document))
  (align (flatten (align-document-child document))))

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

(defun rank+ (left right)
  (%rank (the nonnegative-fixnum
              (+ (rank-overflow left) (rank-overflow right)))
         (the nonnegative-fixnum
              (+ (rank-height left) (rank-height right)))))

(defun rank<= (left right)
  (or (< (rank-overflow left) (rank-overflow right))
      (and (= (rank-overflow left) (rank-overflow right))
           (<= (rank-height left) (rank-height right)))))

(defun rank< (left right)
  (and (rank<= left right)
       (not (and (= (rank-overflow left) (rank-overflow right))
                 (= (rank-height left) (rank-height right))))))

(defun text-rank (cost column length)
  (declare (type nonnegative-fixnum column length))
  (%rank (the nonnegative-fixnum
              (funcall (the function *cost-measure*)
                       (cost-width cost) column length))
         0))

(defstruct (candidate (:constructor %candidate (layout last rank)))
  (layout nil :type document :read-only t)
  (last 0 :type nonnegative-fixnum :read-only t)
  (rank (%rank) :type rank :read-only t))

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

(defun dominates-p (left right)
  (and (<= (candidate-last left) (candidate-last right))
       (rank<= (candidate-rank left) (candidate-rank right))))

(defun empty-frontier ()
  ;; Most observed frontiers contain one or two candidates. Reserve those
  ;; slots up front so the first pushes do not immediately reallocate.
  (make-array 2 :adjustable t :fill-pointer 0))

(defun frontier-add (frontier candidate)
  "Add CANDIDATE destructively, discarding candidates dominated in both
last column and rank. Frontiers are unrestricted adjustable vectors."
  (declare (type (vector t) frontier) (type candidate candidate))
  (when (loop for existing across frontier
              thereis (dominates-p existing candidate))
    (return-from frontier-add frontier))
  (loop with write = 0
        for existing across frontier
        unless (dominates-p candidate existing)
          do (setf (aref frontier write) existing)
             (incf write)
        finally (setf (fill-pointer frontier) write))
  (vector-push-extend candidate frontier)
  frontier)

(defun frontier-union (left right)
  (declare (type (vector t) left right))
  (let ((result (empty-frontier)))
    (loop for candidate across left
          do (frontier-add result candidate))
    (loop for candidate across right
          do (frontier-add result candidate))
    (sort result #'> :key #'candidate-last)))

(defun canonicalize-frontier (frontier)
  (declare (type (vector t) frontier))
  (if (= 1 (length frontier)) (aref frontier 0) frontier))

(deftype evaluation () '(or candidate vector function))

(defun tainted-evaluation (thunk)
  (declare (type function thunk))
  (incf (statistics-taints-deferred (the statistics *statistics*)))
  (lambda ()
    (incf (statistics-taints-forced (the statistics *statistics*)))
    (funcall thunk)))

(defun evaluation-empty-p (evaluation)
  (and (vectorp evaluation) (zerop (length evaluation))))

(defgeneric force-evaluation (evaluation))

(defmethod force-evaluation ((evaluation function))
  (funcall evaluation))

(defmethod force-evaluation ((evaluation candidate)) evaluation)

(defmethod force-evaluation ((evaluation vector))
  (declare (type (vector t) evaluation))
  (when (zerop (length evaluation))
    (error "Cannot choose from an empty frontier"))
  (aref evaluation 0))

(defgeneric merge-evaluations (left right)
  (:documentation
   "Merge like Pretty Expressive's measure sets: a normal frontier always
wins over taint, since taint means that computation has left the bounded
region. If both sides are tainted, retain the left promise."))

(defmethod merge-evaluations ((left vector) (right vector))
  (cond ((evaluation-empty-p left) right)
        ((evaluation-empty-p right) left)
        (t (canonicalize-frontier (frontier-union left right)))))

(defmethod merge-evaluations ((left candidate) (right candidate))
  (cond ((dominates-p left right) left)
        ((dominates-p right left) right)
        (t (let ((frontier (empty-frontier)))
             (frontier-add frontier left)
             (frontier-add frontier right)
             (sort frontier #'> :key #'candidate-last)))))

(defmethod merge-evaluations ((left candidate) (right vector))
  (declare (type (vector t) right))
  (if (evaluation-empty-p right)
      left
      (let ((frontier (empty-frontier)))
        (frontier-add frontier left)
        (loop for candidate across right do (frontier-add frontier candidate))
        (canonicalize-frontier (sort frontier #'> :key #'candidate-last)))))

(defmethod merge-evaluations ((left vector) (right candidate))
  (merge-evaluations right left))

(defmethod merge-evaluations ((left vector) (right function))
  (if (evaluation-empty-p left) right left))

(defmethod merge-evaluations ((left candidate) (right function))
  (declare (ignore right))
  left)

(defmethod merge-evaluations ((left function) (right vector))
  (if (evaluation-empty-p right) left right))

(defmethod merge-evaluations ((left function) (right candidate))
  (declare (ignore left))
  right)

(defmethod merge-evaluations ((left function) (right function))
  (declare (ignore right))
  left)

;;; Recursive evaluator

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

(defgeneric note-evaluation (evaluation))

(defmethod note-evaluation ((evaluation vector))
  (note-frontier evaluation))

(defmethod note-evaluation ((evaluation candidate))
  (let* ((statistics (the statistics *statistics*))
         (histogram (statistics-frontier-histogram statistics)))
    (setf (statistics-frontier-maximum statistics)
          (max 1 (statistics-frontier-maximum statistics)))
    (setf (gethash 1 histogram)
          (the nonnegative-fixnum
               (1+ (the nonnegative-fixnum (gethash 1 histogram 0))))))
  evaluation)

(defmethod note-evaluation ((evaluation function))
  evaluation)

(defun document-context-table (document)
  (or (document-memo-table document)
      (setf (document-memo-table document)
            (make-hash-table :test #'eql))))

(defun memo-context-key (last base limit)
  ;; LAST and BASE are both at most LIMIT here, so this is a collision-free
  ;; row-major encoding of the pair, as in the OCaml implementation.
  (declare (type nonnegative-fixnum last base limit))
  ;; Contexts are deliberately a fixnum domain. As with ranks, callers that
  ;; construct impractically large layouts are outside this implementation's
  ;; numeric contract.
  (the nonnegative-fixnum
       (+ last
          (the nonnegative-fixnum
               (* base
                  (the nonnegative-fixnum
                       (1+ limit)))))))

(defmacro memoized ((document last base) &body body)
  "Evaluate BODY directly for ordinary nodes and cache it at memo checkpoints
whose context lies inside the computation limit."
  (let ((document-var (gensym "DOCUMENT"))
        (last-var (gensym "LAST"))
        (base-var (gensym "BASE"))
        (limit-var (gensym "LIMIT"))
        (contexts-var (gensym "CONTEXTS"))
        (key-var (gensym "KEY"))
        (value-var (gensym "VALUE"))
        (present-var (gensym "PRESENT"))
        (compute-name (gensym "COMPUTE")))
    `(let* ((,document-var ,document)
            (,last-var ,last)
            (,base-var ,base)
            (,limit-var (cost-limit *cost*)))
       (labels ((,compute-name () ,@body))
         (if (and (zerop (document-memo-weight ,document-var))
                  (<= ,last-var ,limit-var)
                  (<= ,base-var ,limit-var))
             (let* ((,contexts-var (document-context-table ,document-var))
                    (,key-var (memo-context-key
                               ,last-var ,base-var ,limit-var)))
               (multiple-value-bind (,value-var ,present-var)
                   (gethash ,key-var ,contexts-var)
                 (if ,present-var
                     (progn
                       (incf (statistics-memo-hits *statistics*))
                       ,value-var)
                     (let ((,value-var (,compute-name)))
                       (setf (gethash ,key-var ,contexts-var) ,value-var)
                       (incf (statistics-memo-entries *statistics*))
                       ,value-var))))
             (,compute-name))))))

(defgeneric exceeds-computation-limit-p (document last base))

(defmethod exceeds-computation-limit-p
    ((document document) last base)
  (declare (type nonnegative-fixnum last base))
  (let ((limit (cost-limit (the cost *cost*))))
    (or (> base limit) (> last limit))))

(defmethod exceeds-computation-limit-p
    ((document text-document) last base)
  (declare (type nonnegative-fixnum last base))
  (let ((limit (cost-limit (the cost *cost*))))
    (or (> base limit)
        (> (+ last (length (text-document-text document))) limit))))

(defgeneric evaluate-document (document last base)
  (:documentation "Evaluate one document node after memo and taint checks."))

(defmethod evaluate-document
    ((document text-document) last base)
  (declare (ignore base) (type nonnegative-fixnum last))
  (let* ((string (text-document-text document))
         (length (length string)))
    (%candidate document (+ last length)
                (text-rank (the cost *cost*) last length))))

(defmethod evaluate-document
    ((document newline-document) last base)
  (declare (ignore last) (type nonnegative-fixnum base))
  (%candidate document base (%rank 0 1)))

(defmethod evaluate-document
    ((document choice-document) last base)
  (declare (type nonnegative-fixnum last base))
  (merge-evaluations
   (evaluate (choice-document-left document) last base)
   (evaluate (choice-document-right document) last base)))

(defmethod evaluate-document
    ((document nest-document) last base)
  (declare (type nonnegative-fixnum last base))
  (let ((amount (nest-document-amount document)))
    (wrap-evaluation
     :nest amount
     (evaluate (nest-document-child document) last
               (the nonnegative-fixnum (+ base amount))))))

(defmethod evaluate-document
    ((document align-document) last base)
  (declare (ignore base) (type nonnegative-fixnum last))
  (wrap-evaluation
   :align 0
   (evaluate (align-document-child document) last last)))

(defmethod evaluate-document
    ((document concatenation-document) last base)
  (declare (type nonnegative-fixnum last base))
  (evaluate-concatenation document last base))

(defun evaluate (document last base)
  (declare (type document document)
           (type nonnegative-fixnum last base))
  (memoized (document last base)
    (incf (statistics-evaluations (the statistics *statistics*)))
    (labels ((core ()
               (note-evaluation (evaluate-document document last base))))
      (if (exceeds-computation-limit-p document last base)
          (tainted-evaluation (lambda () (force-evaluation (core))))
          (core)))))

(defun wrap-frontier (kind amount frontier)
  (declare (type nonnegative-fixnum amount) (type (vector t) frontier))
  (map 'vector
       (lambda (candidate)
         (%candidate
          (ecase kind
            (:nest (nest amount (candidate-layout candidate)))
            (:align (align (candidate-layout candidate))))
          (candidate-last candidate)
          (candidate-rank candidate)))
       frontier))

(defun wrap-candidate (kind amount candidate)
  (%candidate
   (ecase kind
     (:nest (nest amount (candidate-layout candidate)))
     (:align (align (candidate-layout candidate))))
   (candidate-last candidate)
   (candidate-rank candidate)))

(defgeneric wrap-evaluation (kind amount evaluation))

(defmethod wrap-evaluation (kind amount (evaluation vector))
  (wrap-frontier kind amount evaluation))

(defmethod wrap-evaluation (kind amount (evaluation candidate))
  (wrap-candidate kind amount evaluation))

(defmethod wrap-evaluation (kind amount (evaluation function))
  (tainted-evaluation
   (lambda ()
     (wrap-candidate kind amount (force-evaluation evaluation)))))

(defun concatenate-candidates (left right)
  (%candidate
   (concatenate (candidate-layout left) (candidate-layout right))
   (candidate-last right)
   (rank+ (candidate-rank left) (candidate-rank right))))

(defgeneric concatenate-right-evaluation (left right))

(defmethod concatenate-right-evaluation
    (left (right vector))
  (declare (type candidate left) (type (vector t) right))
  (let ((result (empty-frontier)))
    (loop for candidate across right
          do (frontier-add result (concatenate-candidates left candidate)))
    (canonicalize-frontier (sort result #'> :key #'candidate-last))))

(defmethod concatenate-right-evaluation
    (left (right candidate))
  (concatenate-candidates left right))

(defmethod concatenate-right-evaluation
    (left (right function))
  (tainted-evaluation
   (lambda ()
     (concatenate-candidates left (force-evaluation right)))))

(defun concatenate-right (document left base)
  (concatenate-right-evaluation
   left
   (evaluate (concatenation-document-right document)
             (candidate-last left) base)))

(defgeneric concatenate-left-evaluation
    (document base left))

(defmethod concatenate-left-evaluation
    (document base (left function))
  (tainted-evaluation
   (lambda ()
     (let* ((left-candidate (force-evaluation left))
            (right (concatenate-right document left-candidate base)))
       (force-evaluation right)))))

(defmethod concatenate-left-evaluation
    (document base (left vector))
  (declare (type concatenation-document document)
           (type nonnegative-fixnum base) (type (vector t) left))
  (let ((result (empty-frontier)))
    (loop for candidate across left
          do (setf result
                   (merge-evaluations
                    result
                    (concatenate-right document candidate base))))
    result))

(defmethod concatenate-left-evaluation
    (document base (left candidate))
  (concatenate-right document left base))

(defun evaluate-concatenation (document last base)
  (declare (type concatenation-document document)
           (type nonnegative-fixnum last base))
  (concatenate-left-evaluation
   document base
   (evaluate (concatenation-document-left document) last base)))

(defstruct (result (:constructor %result
                       (candidate frontier statistics tainted-p)))
  (candidate nil :type candidate :read-only t)
  (frontier #() :type vector :read-only t)
  (statistics (make-statistics) :type statistics :read-only t)
  (tainted-p nil :type boolean :read-only t))

(defun pick (document cost)
  "Consume and resolve DOCUMENT with computation-width taint. Documents are
single-use search spaces. Ordinary Pareto frontiers are exact and unrestricted;
forced tainted regions deliberately recover one candidate, as in Pretty
Expressive and recursive.zig."
  (when (document-consumed-p document)
    (error "PICK cannot reuse an already consumed document"))
  (setf (document-consumed-p document) t)
  (let ((*cost* cost)
        (*statistics* (make-statistics))
        (*cost-measure* (or *cost-measure* (cost-measure cost))))
    (let* ((evaluation (evaluate document 0 0))
           (tainted-p (functionp evaluation))
           (frontier
             (the (vector t)
                  (etypecase evaluation
                    (function (vector (force-evaluation evaluation)))
                    (candidate (vector evaluation))
                    (vector (the (vector t) evaluation)))))
           (statistics *statistics*))
      (when (zerop (length frontier))
        (error "Document has no layouts"))
      (let ((best (aref frontier 0)))
        (loop for candidate across frontier
              when (rank< (candidate-rank candidate)
                          (candidate-rank best))
                do (setf best candidate))
        (%result best frontier statistics tainted-p)))))

;;; Rendering

(defgeneric render-layout (document stream last base))

(defmethod render-layout ((document text-document) stream last base)
  (declare (ignore base) (type nonnegative-fixnum last))
  (write-string (text-document-text document) stream)
  (the nonnegative-fixnum
       (+ last (length (text-document-text document)))))

(defmethod render-layout ((document newline-document) stream last base)
  (declare (ignore last) (type nonnegative-fixnum base))
  (terpri stream)
  (loop repeat base do (write-char #\Space stream))
  base)

(defmethod render-layout
    ((document concatenation-document) stream last base)
  (declare (type nonnegative-fixnum last base))
  (render-layout
   (concatenation-document-right document) stream
   (render-layout (concatenation-document-left document) stream last base)
   base))

(defmethod render-layout ((document nest-document) stream last base)
  (declare (type nonnegative-fixnum last base))
  (render-layout (nest-document-child document) stream last
                 (the nonnegative-fixnum
                      (+ base (nest-document-amount document)))))

(defmethod render-layout ((document align-document) stream last base)
  (declare (ignore base) (type nonnegative-fixnum last))
  (render-layout (align-document-child document) stream last last))

(defmethod render-layout ((document choice-document) stream last base)
  (declare (ignore stream last base))
  (error "Cannot render an unresolved choice"))

(defun render (candidate &optional stream)
  "Render CANDIDATE. Return a string when STREAM is omitted."
  (if stream
      (progn (render-layout (candidate-layout candidate) stream 0 0) nil)
      (with-output-to-string (output)
        (render-layout (candidate-layout candidate) output 0 0))))

(defun format-document (document cost)
  "Resolve and render DOCUMENT in one call."
  (render (result-candidate (pick document cost))))
