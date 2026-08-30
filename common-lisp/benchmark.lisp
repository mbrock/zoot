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

;;; Reports are rendered by Zoot itself. Cells are padded to shared
;;; column widths and styled with spans, which take no columns and so
;;; never disturb alignment; a cell holding a document, like a frontier
;;; histogram, wraps as an aligned fill inside its column.

(defstruct (cell (:constructor cell (text &key style (align :right))))
  text
  style
  align)

(defun spaced-fill (documents)
  (reduce (lambda (left right) (cat left (choice " " +newline+) right))
          documents))

(defun histogram-document (histogram)
  (spaced-fill
   (loop for key in (sort (loop for key being the hash-keys of histogram
                                collect key)
                          #'<)
         collect (format nil "~D:~:D" key (gethash key histogram)))))

(defun cell-document (cell width last-p)
  (let* ((text (cell-text cell))
         (content
           (cond ((not (stringp text)) (align text))
                 ((and last-p (eq (cell-align cell) :left)) text)
                 ((eq (cell-align cell) :left)
                  (format nil "~VA" width text))
                 (t (format nil "~V@A" width text)))))
    (if (cell-style cell)
        (span (cell-style cell) content)
        content)))

(defun row-document (row widths)
  (let ((document "  "))
    (loop for (cell . remaining) on row
          for width in widths
          for first = t then nil
          unless (equal (cell-text cell) "")
            do (setf document
                     (cat document
                          (if first "" "  ")
                          (cell-document cell width (null remaining)))))
    document))

(defun table-document (rows)
  (let* ((columns (reduce #'max rows :key #'length))
         (widths
           (loop for index below columns
                 collect (reduce #'max rows
                                 :key (lambda (row)
                                        (let ((cell (nth index row)))
                                          (if (and cell
                                                   (stringp
                                                    (cell-text cell)))
                                              (length (cell-text cell))
                                              0)))))))
    (reduce (lambda (left right) (cat left +newline+ right))
            (mapcar (lambda (row) (row-document row widths)) rows))))

(defun section-document (title rows)
  (cat (span "1" title) +newline+ (table-document rows)))

(defun heading-cells (&rest titles)
  (loop for title in titles
        for first = t then nil
        collect (cell title :style "2" :align (if first :left :right))))

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

(defun layout-rows (samples)
  (cons (heading-cells "case" "plan" "build" "chars" "o·i·h" "")
        (mapcar
         (lambda (sample)
           (let ((rank (sample-rank sample)))
             (list (cell (sample-name sample) :style "1" :align :left)
                   (cell (format nil "~,2F ms" (sample-plan-average sample)))
                   (cell (format nil "~,2F ms"
                                 (sample-build-average sample)))
                   (cell (format nil "~:D" (sample-bytes sample)))
                   (cell (format nil "~:D·~:D·~:D"
                                 (rank-overflow rank)
                                 (rank-indentation rank)
                                 (rank-height rank)))
                   (cell (if (sample-tainted-p sample) "tainted" "")
                         :style "33" :align :left))))
         samples)))

(defun search-rows (samples)
  (cons (heading-cells "case" "evaluations" "hits" "rate" "entries"
                       "deferred" "forced")
        (mapcar
         (lambda (sample)
           (let ((statistics (sample-statistics sample)))
             (list (cell (sample-name sample) :style "1" :align :left)
                   (cell (format nil "~:D"
                                 (statistics-evaluations statistics)))
                   (cell (format nil "~:D"
                                 (statistics-memo-hits statistics)))
                   (cell (format nil "~,1F%" (memo-hit-rate statistics)))
                   (cell (format nil "~:D"
                                 (statistics-memo-entries statistics)))
                   (cell (format nil "~:D"
                                 (statistics-taints-deferred statistics)))
                   (cell (format nil "~:D"
                                 (statistics-taints-forced statistics))))))
         samples)))

(defun frontier-rows (samples)
  (cons (list (cell "case" :style "2" :align :left)
              (cell "width" :style "2")
              (cell "sizes" :style "2" :align :left))
        (mapcar
         (lambda (sample)
           (let ((statistics (sample-statistics sample)))
             (list (cell (sample-name sample) :style "1" :align :left)
                   (cell (format nil "~D of ~D"
                                 (sample-frontier-size sample)
                                 (statistics-frontier-maximum statistics)))
                   (cell (histogram-document
                          (statistics-frontier-histogram statistics))))))
         samples)))

(defvar *ansi-report-p* nil
  "Render reports through the pretty-printer's ANSI stream when true.")

(defun report-document (document)
  (let ((target *standard-output*))
    (render (result-candidate (pick document (make-f2 80)))
            (if *ansi-report-p*
                (uiop:symbol-call '#:zoot-sexp '#:make-ansi-stream target)
                target))
    (terpri target)))

(defun report-samples (samples)
  (terpri)
  (report-document
   (reduce (lambda (left right) (cat left +newline+ +newline+ right))
           (list (section-document "Layout" (layout-rows samples))
                 (section-document "Search" (search-rows samples))
                 (section-document "Frontiers"
                                   (frontier-rows samples))))))

(defun memo-hit-rate (statistics)
  (let ((hits (statistics-memo-hits statistics))
        (evaluations (statistics-evaluations statistics)))
    (if (zerop (+ hits evaluations))
        0.0d0
        (* 100.0d0 (/ hits (+ hits evaluations))))))

(defparameter *printer-ready-p* (load-pretty-printer))

(setf *ansi-report-p*
      (and *printer-ready-p*
           (or (equal (sb-ext:posix-getenv "ZOOT_COLOR") "1")
               (interactive-stream-p *standard-output*))))

(defun benchmark-printer (runs)
  "Time end-to-end pretty-printing of the corpus source file."
  (if *printer-ready-p*
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
             (cat (span "1" "Printer") +newline+ "  "
                  (align
                   (spaced-fill
                    (list (span "1" (file-namestring path))
                          (span "1" (format nil "~,2F ms/run" average))
                          (format nil "~D runs" runs)
                          (format nil "~:D chars" (length source))
                          (format nil "~:D → ~:D lines"
                                  (1+ (count #\Newline source))
                                  (1+ (count #\Newline output)))
                          (span "2" (namestring path))))))))))
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
