(in-package #:zoot)

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
                   0
                   0)))
    (verbatim-document
     (let ((string (verbatim-document-text document))
           (cost (the cost *cost*))
           (overflow 0)
           (height 0)
           (column last)
           (start 0))
       (declare (type nonnegative-fixnum overflow height column start))
       (loop
         (let* ((break (position #\Newline string :start start))
                (end (or break (length string)))
                (length (- end start)))
           (declare (type nonnegative-fixnum end length))
           (setf overflow
                 (the nonnegative-fixnum
                      (+ overflow (text-overflow cost column length))))
           (when (null break)
             (return (%candidate document
                                 (the nonnegative-fixnum (+ column length))
                                 overflow 0 height)))
           (incf height)
           (setf column 0 start (1+ break))))))
    (choice-document
     (merge-evaluations
      (evaluate (choice-document-left document) last base)
      (evaluate (choice-document-right document) last base)))
    (character
     ;; Track the indentation of the line begun by this break.
     (%candidate document base 0 base 1))
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
    (span-document
     (wrap-evaluation
      :span (span-document-meta document)
      (evaluate (span-document-child document) last base)))
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
     (:align (%align-document (candidate-layout candidate)))
     (:span (%span-document amount (candidate-layout candidate))))
   (candidate-last candidate)
   (candidate-overflow candidate)
   (candidate-indentation candidate)
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
        (+ (candidate-indentation left) (candidate-indentation right)))
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
