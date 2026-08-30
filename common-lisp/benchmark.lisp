(require "asdf")
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot")

(defpackage #:zoot-benchmark
  (:use #:cl #:zoot)
  (:shadowing-import-from #:zoot #:concatenate))

(in-package #:zoot-benchmark)

(defun join-documents (separator documents)
  (if (null documents)
      (text "")
      (reduce (lambda (left right)
                (cat left separator right))
              (rest documents)
              :initial-value (first documents))))

(defun call-document (items)
  "A token-preserving choice between horizontal and vertical S-expression
layout. Both branches contain exactly the same non-whitespace tokens."
  (let ((horizontal (join-documents (text " ") items))
        (vertical (apply #'vcat items)))
    (cat (text "(")
         (align (choice horizontal vertical))
         (text ")"))))

(defun ternary-document (depth)
  "Construct a fresh full ternary expression tree with choices at each call."
  (let ((ordinal 0))
    (labels ((name (prefix)
               (prog1 (text (format nil "~A~D" prefix ordinal))
                 (incf ordinal)))
             (walk (remaining)
               (let ((operator (name "f")))
                 (if (zerop remaining)
                     (call-document
                      (list operator (name "x") (name "x") (name "x")))
                     (call-document
                      (list operator
                            (walk (1- remaining))
                            (walk (1- remaining))
                            (walk (1- remaining))))))))
      (walk depth))))

(defun shared-document (depth)
  "Construct a DAG: each level concatenates the same child on both branches."
  (labels ((walk (remaining)
             (if (zerop remaining)
                 (choice (text "shared-wide")
                         (cat +newline+ (text "s")))
                 (let ((child (walk (1- remaining))))
                   (choice
                    (cat (text "(") child (text " ") child (text ")"))
                    (cat (text "(") (align (vcat child child)) (text ")")))))))
    (walk depth)))

(defun tainted-document (count)
  "An overflowing prefix followed by fitting alternatives after newlines."
  (apply #'cat
         (loop repeat count
               append (list (text "unavoidably-wide-token")
                            +newline+
                            (choice (text "also-far-too-wide")
                                    (text "ok"))))))

(defstruct benchmark
  name
  document
  cost)

(defun histogram-string (histogram)
  (with-output-to-string (stream)
    (let ((first t))
      (dolist (key (sort (loop for key being the hash-keys of histogram
                               collect key)
                         #'<))
        (unless first (write-string ", " stream))
        (setf first nil)
        (format stream "~D:~D" key (gethash key histogram))))))

(defun milliseconds (ticks)
  (* 1000.0d0 (/ ticks internal-time-units-per-second)))

(defstruct sample
  name
  runs
  elapsed
  average
  bytes
  rank
  frontier-size
  statistics
  tainted-p)

(defun time-benchmark (benchmark runs)
  ;; Warm memoized code and the compiler before taking samples. Each PICK still
  ;; owns a fresh evaluator and memo table.
  (pick (benchmark-document benchmark) (benchmark-cost benchmark))
  (let ((start (get-internal-real-time))
        (last-result nil))
    (dotimes (run runs)
      (declare (ignore run))
      (setf last-result
            (pick (benchmark-document benchmark) (benchmark-cost benchmark))))
    (let* ((elapsed (milliseconds (- (get-internal-real-time) start)))
           (candidate (result-candidate last-result))
           (rank (candidate-rank candidate))
           (statistics (result-statistics last-result)))
      (make-sample
       :name (benchmark-name benchmark)
       :runs runs
       :elapsed elapsed
       :average (/ elapsed runs)
       :bytes (length (render candidate))
       :rank rank
       :frontier-size (length (result-frontier last-result))
       :statistics statistics
       :tainted-p (result-tainted-p last-result)))))

(defun print-heading ()
  (format t "~&Common Lisp Zoot benchmark (~A ~A)~%"
          (lisp-implementation-type) (lisp-implementation-version)))

(defun print-performance-table (samples)
  (format t "~%Performance and selected layout~%")
  (format t "~18A  ~5A  ~10A  ~9A  ~8A  ~10A  ~8A  ~7A~%"
          "case" "runs" "total ms" "mean ms" "chars" "overflow" "newlines"
          "tainted")
  (format t "~18A  ~5A  ~10A  ~9A  ~8A  ~10A  ~8A  ~7A~%"
          "------------------" "-----" "----------" "---------" "--------"
          "----------" "--------" "-------")
  (dolist (sample samples)
    (let ((rank (sample-rank sample)))
      (format t "~18A  ~5D  ~10,2F  ~9,3F  ~8D  ~10D  ~8D  ~7A~%"
              (sample-name sample)
              (sample-runs sample)
              (sample-elapsed sample)
              (sample-average sample)
              (sample-bytes sample)
              (rank-overflow rank)
              (rank-height rank)
              (if (sample-tainted-p sample) "yes" "no")))))

(defun memo-hit-rate (statistics)
  (let ((hits (statistics-memo-hits statistics))
        (evaluations (statistics-evaluations statistics)))
    (if (zerop (+ hits evaluations))
        0.0d0
        (* 100.0d0 (/ hits (+ hits evaluations))))))

(defun print-search-table (samples)
  (format t "~%Search and bounded computation~%")
  (format t "~18A  ~11A  ~10A  ~8A  ~8A  ~9A  ~7A~%"
          "case" "evaluations" "memo hits" "hit rate" "entries" "deferred"
          "forced")
  (format t "~18A  ~11A  ~10A  ~8A  ~8A  ~9A  ~7A~%"
          "------------------" "-----------" "----------" "--------" "--------"
          "---------" "-------")
  (dolist (sample samples)
    (let ((statistics (sample-statistics sample)))
      (format t "~18A  ~11D  ~10D  ~7,2F%  ~8D  ~9D  ~7D~%"
              (sample-name sample)
              (statistics-evaluations statistics)
              (statistics-memo-hits statistics)
              (memo-hit-rate statistics)
              (statistics-memo-entries statistics)
              (statistics-taints-deferred statistics)
              (statistics-taints-forced statistics)))))

(defun print-frontier-table (samples)
  (format t "~%Pareto frontiers~%")
  (format t "~18A  ~5A  ~5A  ~A~%" "case" "root" "max" "size:occurrences")
  (format t "~18A  ~5A  ~5A  ~A~%" "------------------" "-----" "-----"
          "----------------")
  (dolist (sample samples)
    (let ((statistics (sample-statistics sample)))
      (format t "~18A  ~5D  ~5D  ~A~%"
              (sample-name sample)
              (sample-frontier-size sample)
              (statistics-frontier-maximum statistics)
              (histogram-string
               (statistics-frontier-histogram statistics))))))

(defun command-line-runs ()
  (let ((argument (second sb-ext:*posix-argv*)))
    (if argument
        (or (parse-integer argument :junk-allowed t) 10)
        10)))

(let* ((runs (command-line-runs))
       (benchmarks
         (list
          (make-benchmark :name "ternary-depth-3"
                          :document (ternary-document 3)
                          :cost (make-f2 80))
          (make-benchmark :name "ternary-depth-4"
                          :document (ternary-document 4)
                          :cost (make-f2 80))
          (make-benchmark :name "shared-depth-9"
                          :document (shared-document 9)
                          :cost (make-f2 60))
          (make-benchmark :name "tainted-lines-512"
                          :document (tainted-document 512)
                          :cost (make-f2 12 :computation-width 14)))))
  (unless (plusp runs)
    (error "RUNS must be a positive integer, got ~S" runs))
  (print-heading)
  (let ((samples (mapcar (lambda (benchmark)
                           (time-benchmark benchmark runs))
                         benchmarks)))
    (print-performance-table samples)
    (print-search-table samples)
    (print-frontier-table samples)))
