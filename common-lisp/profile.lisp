(require :sb-sprof)
(require "asdf")
(if (string= (or (sb-ext:posix-getenv "ZOOT_STATISTICS") "0") "1")
    (pushnew :zoot-statistics *features*)
    (setf *features* (remove :zoot-statistics *features*)))
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot" :force t)
(load (merge-pathnames "benchmark-workloads.lisp" *load-truename*))

(in-package #:zoot-benchmark)

(defun command-line-integer (index default)
  (let ((argument (nth index sb-ext:*posix-argv*)))
    (if argument
        (or (parse-integer argument :junk-allowed t) default)
        default)))

(let ((samples (command-line-integer 1 1500))
      (depth (command-line-integer 2 4))
      (mode (or (nth 3 sb-ext:*posix-argv*) "ternary"))
      (cost (make-f2 80)))
  (unless (plusp samples)
    (error "SAMPLES must be positive, got ~S" samples))
  (unless (plusp depth)
    (error "DEPTH must be positive, got ~S" depth))
  (cond
    ((string= mode "format")
     (unless (load-pretty-printer)
       (error "Eclector is unavailable; cannot profile the pretty-printer"))
     (let* ((path (corpus-path))
            (source (read-corpus path)))
       ;; Warm compilation and profiler machinery before sampling.
       (format-corpus source)
       (format t "~&Common Lisp Zoot printer profile: ~A, ~D CPU samples, statistics ~:[off~;on~]~%"
               (namestring path) samples
               (member :zoot-statistics *features*))
       (sb-sprof:with-profiling
           (:mode :cpu
            :sample-interval 0.001d0
            :max-samples samples
            :loop t
            :reset t
            :report :flat)
         (format-corpus source))))
    (t
     ;; Warm compilation, caches unrelated to document memoization, and
     ;; profiler machinery before resetting the sample buffer.
     (pick (ternary-document depth) cost)
     (format t "~&Common Lisp Zoot profile: ternary depth ~D, ~D CPU samples, statistics ~:[off~;on~]~%"
             depth samples (member :zoot-statistics *features*))
     (sb-sprof:with-profiling
         (:mode :cpu
          :sample-interval 0.001d0
          :max-samples samples
          :loop t
          :reset t
          :report :flat)
       (pick (ternary-document depth) cost)))))
