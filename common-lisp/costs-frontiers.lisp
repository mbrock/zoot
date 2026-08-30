(in-package #:zoot)

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

(defstruct (rank (:constructor %rank
                     (&optional (overflow 0) (indentation 0) (height 0))))
  (overflow 0 :type nonnegative-fixnum :read-only t)
  (indentation 0 :type nonnegative-fixnum :read-only t)
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
(defstruct (candidate
            (:constructor %candidate
                (layout last overflow indentation height)))
  (layout nil :type document :read-only t)
  (last 0 :type nonnegative-fixnum :read-only t)
  (overflow 0 :type nonnegative-fixnum :read-only t)
  (indentation 0 :type nonnegative-fixnum :read-only t)
  (height 0 :type nonnegative-fixnum :read-only t))

(defun candidate-rank (candidate)
  "The candidate's (overflow, height) rank as a fresh RANK object."
  (%rank (candidate-overflow candidate)
         (candidate-indentation candidate)
         (candidate-height candidate)))

(declaim (inline better-rank-p))
(defun better-rank-p (left right)
  "Strict lexicographic (overflow, indentation, height) candidate order."
  (declare (type candidate left right))
  (or (< (candidate-overflow left) (candidate-overflow right))
      (and (= (candidate-overflow left) (candidate-overflow right))
           (or (< (candidate-indentation left)
                  (candidate-indentation right))
               (and (= (candidate-indentation left)
                       (candidate-indentation right))
                    (< (candidate-height left)
                       (candidate-height right)))))))

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
                (or (< (candidate-indentation left)
                       (candidate-indentation right))
                    (and (= (candidate-indentation left)
                            (candidate-indentation right))
                         (<= (candidate-height left)
                             (candidate-height right))))))))

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
  (kind :nest :type (member :nest :align :span) :read-only t)
  ;; The nest amount, or a span's meta.
  (amount 0 :read-only t)
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
