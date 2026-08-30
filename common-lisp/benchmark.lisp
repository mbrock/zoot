(require "asdf")
(pushnew :zoot-statistics *features*)
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot" :force t)
(load (merge-pathnames "benchmark-workloads.lisp" *load-truename*))

(in-package #:zoot-benchmark)

(defstruct benchmark
  name
  builder
  cost)

;;; Reports are rendered by Zoot itself: each sample is one record whose
;;; comma-separated clauses break optimally within the page width.

(defun clause-join (documents)
  "Comma-separate DOCUMENTS, each comma a potential line break."
  (reduce (lambda (left right)
            (cat left "," (choice " " +newline+) right))
          documents))

(defun spaced-fill (documents)
  (reduce (lambda (left right) (cat left (choice " " +newline+) right))
          documents))

(defun histogram-document (histogram)
  (spaced-fill
   (loop for key in (sort (loop for key being the hash-keys of histogram
                                collect key)
                          #'<)
         collect (format nil "~D:~D" key (gethash key histogram)))))

(defun milliseconds (ticks)
  (* 1000.0d0 (/ ticks internal-time-units-per-second)))

(defstruct sample
  name
  runs
  total-average
  build-average
  plan-average
  bytes
  rank
  frontier-size
  statistics
  tainted-p)

(defun time-benchmark (benchmark runs)
  ;; Warm compiled paths with a disposable document. Measured iterations then
  ;; build and consume one fresh document apiece.
  (pick (funcall (benchmark-builder benchmark)) (benchmark-cost benchmark))
  (let ((total-start (get-internal-real-time))
        (build-ticks 0)
        (plan-ticks 0)
        (last-result nil))
    (dotimes (run runs)
      (declare (ignore run))
      (let* ((build-start (get-internal-real-time))
             (document (funcall (benchmark-builder benchmark)))
             (plan-start (get-internal-real-time)))
        (incf build-ticks (- plan-start build-start))
        (setf last-result (pick document (benchmark-cost benchmark)))
        (incf plan-ticks (- (get-internal-real-time) plan-start))))
    (let* ((total-ticks (- (get-internal-real-time) total-start))
           (candidate (result-candidate last-result))
           (rank (candidate-rank candidate))
           (statistics (result-statistics last-result)))
      (make-sample
       :name (benchmark-name benchmark)
       :runs runs
       :total-average (/ (milliseconds total-ticks) runs)
       :build-average (/ (milliseconds build-ticks) runs)
       :plan-average (/ (milliseconds plan-ticks) runs)
       :bytes (length (render candidate))
       :rank rank
       :frontier-size (length (result-frontier last-result))
       :statistics statistics
       :tainted-p (result-tainted-p last-result)))))

(defun print-heading ()
  (format t "~&Common Lisp Zoot benchmark (~A ~A)~%"
          (lisp-implementation-type) (lisp-implementation-version)))

(defun sample-document (sample)
  (let ((rank (sample-rank sample))
        (statistics (sample-statistics sample)))
    (cat (sample-name sample) ":"
         (nest 2
               (cat " "
                    (clause-join
                     (append
                      (list (format nil "~D runs"
                                    (sample-runs sample))
                            (format nil "~,3F ms plan"
                                    (sample-plan-average sample))
                            (format nil "~,3F ms build"
                                    (sample-build-average sample))
                            (format nil "~D chars"
                                    (sample-bytes sample))
                            (format nil "rank (~D ~D ~D)"
                                    (rank-overflow rank)
                                    (rank-indentation rank)
                                    (rank-height rank)))
                      (when (sample-tainted-p sample)
                        (list "tainted"))
                      (list (format nil "~D evaluations"
                                    (statistics-evaluations statistics))
                            (format nil "~D memo hits (~,2F%)"
                                    (statistics-memo-hits statistics)
                                    (memo-hit-rate statistics))
                            (format nil "~D memo entries"
                                    (statistics-memo-entries statistics))
                            (format nil "~D taints deferred"
                                    (statistics-taints-deferred statistics))
                            (format nil "~D forced"
                                    (statistics-taints-forced statistics))
                            (cat (format nil "frontier ~D wide of ~D ("
                                         (sample-frontier-size sample)
                                         (statistics-frontier-maximum
                                          statistics))
                                 (align (histogram-document
                                         (statistics-frontier-histogram
                                          statistics)))
                                 ")")))))))))

(defun report-document (document)
  (render (result-candidate (pick document (make-f2 80)))
          *standard-output*)
  (terpri))

(defun report-samples (samples)
  (terpri)
  (report-document
   (reduce (lambda (left right) (cat left +newline+ +newline+ right))
           (mapcar #'sample-document samples))))

(defun memo-hit-rate (statistics)
  (let ((hits (statistics-memo-hits statistics))
        (evaluations (statistics-evaluations statistics)))
    (if (zerop (+ hits evaluations))
        0.0d0
        (* 100.0d0 (/ hits (+ hits evaluations))))))

(defun benchmark-printer (runs)
  "Time end-to-end pretty-printing of the corpus source file."
  (if (load-pretty-printer)
      (let* ((path (corpus-path))
             (source (read-corpus path))
             (output (format-corpus source)))
        (let ((start (get-internal-real-time)))
          (dotimes (run runs)
            (declare (ignore run))
            (setf output (format-corpus source)))
          (let ((average (/ (milliseconds (- (get-internal-real-time)
                                             start))
                            runs)))
            (terpri)
            (report-document
             (cat "pretty-printer " (file-namestring path) ":"
                  (nest 2
                        (cat " "
                             (clause-join
                              (list (format nil "~D runs" runs)
                                    (format nil "~,3F ms/run" average)
                                    (format nil "~D chars"
                                            (length source))
                                    (format nil "~D lines in"
                                            (1+ (count #\Newline source)))
                                    (format nil "~D lines out"
                                            (1+ (count #\Newline output)))
                                    (format nil "corpus ~A"
                                            (namestring path)))))))))))
      (format t "~%Pretty-printer benchmark skipped: Eclector unavailable~%")))

(defun command-line-runs ()
  (let ((argument (second sb-ext:*posix-argv*)))
    (if argument
        (or (parse-integer argument :junk-allowed t) 10)
        10)))

(let* ((runs (command-line-runs))
       (benchmarks
         (list
          (make-benchmark :name "ternary-depth-3"
                          :builder (lambda () (ternary-document 3))
                          :cost (make-f2 80))
          (make-benchmark :name "ternary-depth-4"
                          :builder (lambda () (ternary-document 4))
                          :cost (make-f2 80))
          (make-benchmark :name "shared-depth-9"
                          :builder (lambda () (shared-document 9))
                          :cost (make-f2 60))
          (make-benchmark :name "tainted-lines-512"
                          :builder (lambda () (tainted-document 512))
                          :cost (make-f2 12 :computation-width 14)))))
  (unless (plusp runs)
    (error "RUNS must be a positive integer, got ~S" runs))
  (print-heading)
  (report-samples (mapcar (lambda (benchmark)
                            (time-benchmark benchmark runs))
                          benchmarks))
  (benchmark-printer (max 1 (ceiling runs 20))))
