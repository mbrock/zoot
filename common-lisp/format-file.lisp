;;; Usage: sbcl --script format-file.lisp FILE [WIDTH]
;;; Pretty-prints a Lisp source file to standard output.

(require "asdf")
(setf *features* (remove :zoot-statistics *features*))
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot/sexp")

(let* ((arguments (rest sb-ext:*posix-argv*))
       (path (first arguments))
       (width (if (second arguments)
                  (parse-integer (second arguments))
                  80)))
  (unless path
    (format *error-output* "usage: format-file.lisp FILE [WIDTH]~%")
    (sb-ext:exit :code 1))
  (write-string (zoot-sexp:format-file path :width width)))
