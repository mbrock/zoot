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

;;; Documents

(defconstant +initial-memo-weight+ 6
  "Number of structural levels between memo checkpoints, as in the OCaml
reference implementation (its PARAM_MEMO_LIMIT is 7, with initial weight 6).")

(defstruct (document (:constructor nil))
  (memo-weight +initial-memo-weight+
               :type (integer 0 6)
               :read-only t)
  ;; Transient evaluator-owned state. The table itself is retained between
  ;; picks to reuse its allocation, but its entries never cross a pick.
  (memo-owner nil)
  (memo-table nil :type (or null hash-table)))

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
  (amount 0 :type (integer 0) :read-only t)
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
  (check-type amount (integer 0))
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

(defun linear-overflow-cost (page-width column length)
  "Additional linear overflow caused by placing LENGTH characters at COLUMN."
  (max 0 (- (+ column length) (max page-width column))))

(defun squared-overflow-cost (page-width column length)
  "Increase in squared line overflow caused by a text placement."
  (let* ((old-overflow (max 0 (- column page-width)))
         (new-text-overflow
           (max 0 (- (+ column length) (max page-width column)))))
    (* new-text-overflow (+ (* 2 old-overflow) new-text-overflow))))

(defstruct (cost (:constructor %cost (measure width limit)))
  (measure #'squared-overflow-cost :type function :read-only t)
  (width 80 :type (integer 0) :read-only t)
  (limit 96 :type (integer 0) :read-only t))

(defun default-computation-width (page-width)
  (+ page-width (floor page-width 5)))

(defun make-f1 (page-width &key computation-width)
  "Minimize linear overflow, then newline count (paper Example 3.4)."
  (%cost #'linear-overflow-cost page-width
         (or computation-width (default-computation-width page-width))))

(defun make-f2 (page-width &key computation-width)
  "Minimize squared overflow, then newline count (paper Example 3.5)."
  (%cost #'squared-overflow-cost page-width
         (or computation-width (default-computation-width page-width))))

(defstruct (rank (:constructor %rank (&optional (overflow 0) (height 0))))
  (overflow 0 :type (integer 0) :read-only t)
  (height 0 :type (integer 0) :read-only t))

(defun rank+ (left right)
  (%rank (+ (rank-overflow left) (rank-overflow right))
         (+ (rank-height left) (rank-height right))))

(defun rank<= (left right)
  (or (< (rank-overflow left) (rank-overflow right))
      (and (= (rank-overflow left) (rank-overflow right))
           (<= (rank-height left) (rank-height right)))))

(defun rank< (left right)
  (and (rank<= left right)
       (not (and (= (rank-overflow left) (rank-overflow right))
                 (= (rank-height left) (rank-height right))))))

(defun text-rank (cost column length)
  (%rank (funcall *cost-measure* (cost-width cost) column length) 0))

(defstruct (candidate (:constructor %candidate (layout last rank)))
  (layout nil :type document :read-only t)
  (last 0 :type (integer 0) :read-only t)
  (rank (%rank) :type rank :read-only t))

(defun dominates-p (left right)
  (and (<= (candidate-last left) (candidate-last right))
       (rank<= (candidate-rank left) (candidate-rank right))))

(defun empty-frontier ()
  (make-array 0 :adjustable t :fill-pointer 0))

(defun frontier-add (frontier candidate)
  "Add CANDIDATE destructively, discarding candidates dominated in both
last column and rank. Frontiers are unrestricted adjustable vectors."
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

(defun frontier-union (&rest frontiers)
  (let ((result (empty-frontier)))
    (dolist (frontier frontiers)
      (loop for candidate across frontier
            do (frontier-add result candidate)))
    (sort result #'> :key #'candidate-last)))

(deftype evaluation () '(or vector function))

(defun tainted-evaluation (evaluator thunk)
  (incf (statistics-taints-deferred (evaluator-statistics evaluator)))
  (lambda ()
    (incf (statistics-taints-forced (evaluator-statistics evaluator)))
    (funcall thunk)))

(defun evaluation-empty-p (evaluation)
  (and (vectorp evaluation) (zerop (length evaluation))))

(defgeneric force-evaluation (evaluation))

(defmethod force-evaluation ((evaluation function))
  (funcall evaluation))

(defmethod force-evaluation ((evaluation vector))
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
        (t (frontier-union left right))))

(defmethod merge-evaluations ((left vector) (right function))
  (if (evaluation-empty-p left) right left))

(defmethod merge-evaluations ((left function) (right vector))
  (if (evaluation-empty-p right) left right))

(defmethod merge-evaluations ((left function) (right function))
  (declare (ignore right))
  left)

;;; Recursive evaluator

(defstruct statistics
  (evaluations 0 :type (integer 0))
  (memo-hits 0 :type (integer 0))
  (memo-entries 0 :type (integer 0))
  (taints-deferred 0 :type (integer 0))
  (taints-forced 0 :type (integer 0))
  (frontier-maximum 0 :type (integer 0))
  (frontier-histogram (make-hash-table) :type hash-table))

(defstruct (evaluator (:constructor %evaluator (cost memoize)))
  (cost (make-f2 80) :type cost :read-only t)
  (memoize t :type boolean :read-only t)
  (memo-token (list nil) :read-only t)
  (memoized-documents nil :type list)
  (statistics (make-statistics) :type statistics))

(defun note-frontier (evaluator frontier)
  (let* ((statistics (evaluator-statistics evaluator))
         (length (length frontier))
         (histogram (statistics-frontier-histogram statistics)))
    (setf (statistics-frontier-maximum statistics)
          (max length (statistics-frontier-maximum statistics)))
    (incf (gethash length histogram 0)))
  frontier)

(defgeneric note-evaluation (evaluator evaluation))

(defmethod note-evaluation (evaluator (evaluation vector))
  (note-frontier evaluator evaluation))

(defmethod note-evaluation (evaluator (evaluation function))
  (declare (ignore evaluator))
  evaluation)

(defun document-context-table (evaluator document)
  (let ((token (evaluator-memo-token evaluator)))
    (unless (eq token (document-memo-owner document))
      (when (document-memo-owner document)
        (error "Concurrent PICK calls cannot share document nodes yet"))
      (let ((table (or (document-memo-table document)
                       (setf (document-memo-table document)
                             (make-hash-table :test #'eql)))))
        (clrhash table)
        (setf (document-memo-owner document) token)
        (push document (evaluator-memoized-documents evaluator))))
    (document-memo-table document)))

(defun release-context-tables (evaluator)
  (dolist (document (evaluator-memoized-documents evaluator))
    (clrhash (document-memo-table document))
    (setf (document-memo-owner document) nil))
  (setf (evaluator-memoized-documents evaluator) nil))

(defun memo-context-key (evaluator last base)
  ;; LAST and BASE are both at most LIMIT here, so this is a collision-free
  ;; row-major encoding of the pair, as in the OCaml implementation.
  (+ last (* base (1+ (cost-limit (evaluator-cost evaluator))))))

(defun memoized (evaluator document last base thunk)
  (unless (and (evaluator-memoize evaluator)
               (zerop (document-memo-weight document))
               (<= last (cost-limit (evaluator-cost evaluator)))
               (<= base (cost-limit (evaluator-cost evaluator))))
    (return-from memoized (funcall thunk)))
  (let* ((contexts (document-context-table evaluator document))
         (key (memo-context-key evaluator last base)))
    (multiple-value-bind (frontier present-p) (gethash key contexts)
      (if present-p
          (progn
            (incf (statistics-memo-hits (evaluator-statistics evaluator)))
            frontier)
          (prog1 (setf (gethash key contexts) (funcall thunk))
            (incf (statistics-memo-entries
                   (evaluator-statistics evaluator))))))))

(defgeneric exceeds-computation-limit-p (evaluator document last base))

(defmethod exceeds-computation-limit-p
    (evaluator (document document) last base)
  (let ((limit (cost-limit (evaluator-cost evaluator))))
    (or (> base limit) (> last limit))))

(defmethod exceeds-computation-limit-p
    (evaluator (document text-document) last base)
  (let ((limit (cost-limit (evaluator-cost evaluator))))
    (or (> base limit)
        (> (+ last (length (text-document-text document))) limit))))

(defgeneric evaluate-document (evaluator document last base)
  (:documentation "Evaluate one document node after memo and taint checks."))

(defmethod evaluate-document
    (evaluator (document text-document) last base)
  (declare (ignore base))
  (let* ((string (text-document-text document))
         (length (length string)))
    (vector
     (%candidate document (+ last length)
                 (text-rank (evaluator-cost evaluator) last length)))))

(defmethod evaluate-document
    (evaluator (document newline-document) last base)
  (declare (ignore evaluator last))
  (vector (%candidate document base (%rank 0 1))))

(defmethod evaluate-document
    (evaluator (document choice-document) last base)
  (merge-evaluations
   (evaluate evaluator (choice-document-left document) last base)
   (evaluate evaluator (choice-document-right document) last base)))

(defmethod evaluate-document
    (evaluator (document nest-document) last base)
  (let ((amount (nest-document-amount document)))
    (wrap-evaluation
     evaluator :nest amount
     (evaluate evaluator (nest-document-child document) last (+ base amount)))))

(defmethod evaluate-document
    (evaluator (document align-document) last base)
  (declare (ignore base))
  (wrap-evaluation
   evaluator :align 0
   (evaluate evaluator (align-document-child document) last last)))

(defmethod evaluate-document
    (evaluator (document concatenation-document) last base)
  (evaluate-concatenation evaluator document last base))

(defun evaluate (evaluator document last base)
  (memoized
   evaluator document last base
   (lambda ()
     (incf (statistics-evaluations (evaluator-statistics evaluator)))
     (labels ((core ()
                (note-evaluation
                 evaluator
                 (evaluate-document evaluator document last base))))
       (if (exceeds-computation-limit-p evaluator document last base)
           (tainted-evaluation evaluator
                               (lambda () (force-evaluation (core))))
           (core))))))

(defun wrap-frontier (kind amount frontier)
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

(defgeneric wrap-evaluation (evaluator kind amount evaluation))

(defmethod wrap-evaluation (evaluator kind amount (evaluation vector))
  (declare (ignore evaluator))
  (wrap-frontier kind amount evaluation))

(defmethod wrap-evaluation (evaluator kind amount (evaluation function))
  (tainted-evaluation
   evaluator
   (lambda ()
     (wrap-candidate kind amount (force-evaluation evaluation)))))

(defun concatenate-candidates (left right)
  (%candidate
   (concatenate (candidate-layout left) (candidate-layout right))
   (candidate-last right)
   (rank+ (candidate-rank left) (candidate-rank right))))

(defgeneric concatenate-right-evaluation (evaluator left right))

(defmethod concatenate-right-evaluation
    (evaluator left (right vector))
  (declare (ignore evaluator))
  (let ((result (empty-frontier)))
    (loop for candidate across right
          do (frontier-add result (concatenate-candidates left candidate)))
    (sort result #'> :key #'candidate-last)))

(defmethod concatenate-right-evaluation
    (evaluator left (right function))
  (tainted-evaluation
   evaluator
   (lambda ()
     (concatenate-candidates left (force-evaluation right)))))

(defun concatenate-right (evaluator document left base)
  (concatenate-right-evaluation
   evaluator left
   (evaluate evaluator (concatenation-document-right document)
             (candidate-last left) base)))

(defgeneric concatenate-left-evaluation
    (evaluator document base left))

(defmethod concatenate-left-evaluation
    (evaluator document base (left function))
  (tainted-evaluation
   evaluator
   (lambda ()
     (let* ((left-candidate (force-evaluation left))
            (right (concatenate-right evaluator document left-candidate base)))
       (force-evaluation right)))))

(defmethod concatenate-left-evaluation
    (evaluator document base (left vector))
  (let ((result (empty-frontier)))
    (loop for candidate across left
          do (setf result
                   (merge-evaluations
                    result
                    (concatenate-right evaluator document candidate base))))
    result))

(defun evaluate-concatenation (evaluator document last base)
  (concatenate-left-evaluation
   evaluator document base
   (evaluate evaluator (concatenation-document-left document) last base)))

(defstruct (result (:constructor %result
                       (candidate frontier statistics tainted-p)))
  (candidate nil :type candidate :read-only t)
  (frontier #() :type vector :read-only t)
  (statistics (make-statistics) :type statistics :read-only t)
  (tainted-p nil :type boolean :read-only t))

(defun pick (document cost &key (memoize t))
  "Resolve DOCUMENT with computation-width taint. Ordinary Pareto frontiers
are exact and unrestricted; forced tainted regions deliberately recover one
candidate, as in Pretty Expressive and recursive.zig."
  (let ((evaluator (%evaluator cost memoize))
        (*cost-measure* (or *cost-measure* (cost-measure cost))))
    (unwind-protect
         (let* ((evaluation (evaluate evaluator document 0 0))
                (tainted-p (functionp evaluation))
                (frontier
                  (if tainted-p
                      (vector (force-evaluation evaluation))
                      evaluation))
                (statistics (evaluator-statistics evaluator)))
           (when (zerop (length frontier))
             (error "Document has no layouts"))
           (let ((best (aref frontier 0)))
             (loop for candidate across frontier
                   when (rank< (candidate-rank candidate)
                               (candidate-rank best))
                     do (setf best candidate))
             (%result best frontier statistics tainted-p)))
      (release-context-tables evaluator))))

;;; Rendering

(defgeneric render-layout (document stream last base))

(defmethod render-layout ((document text-document) stream last base)
  (declare (ignore base))
  (write-string (text-document-text document) stream)
  (+ last (length (text-document-text document))))

(defmethod render-layout ((document newline-document) stream last base)
  (declare (ignore last))
  (terpri stream)
  (dotimes (index base)
    (declare (ignore index))
    (write-char #\Space stream))
  base)

(defmethod render-layout
    ((document concatenation-document) stream last base)
  (render-layout
   (concatenation-document-right document) stream
   (render-layout (concatenation-document-left document) stream last base)
   base))

(defmethod render-layout ((document nest-document) stream last base)
  (render-layout (nest-document-child document) stream last
                 (+ base (nest-document-amount document))))

(defmethod render-layout ((document align-document) stream last base)
  (declare (ignore base))
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

(defun format-document (document cost &key (memoize t))
  "Resolve and render DOCUMENT in one call."
  (render (result-candidate (pick document cost :memoize memoize))))
