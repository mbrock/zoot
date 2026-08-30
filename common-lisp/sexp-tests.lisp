(require "asdf")
(setf *features* (remove :zoot-statistics *features*))
(handler-case (asdf:load-system "eclector")
  (error ()
    (load (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))
    (asdf:load-system "eclector")))
(asdf:load-asd (merge-pathnames "zoot.asd" *load-truename*))
(asdf:load-system "zoot/sexp" :force t)

(defvar *tests* 0)

(defun check-format (expected source width)
  (incf *tests*)
  (let ((actual (zoot-sexp:format-source source :width width)))
    (unless (string= expected actual)
      (error "format differs:~%expected:~%~Aactual:~%~A" expected actual))))

(check-format
 (format nil "(cond~%  ((foo x)~%    (one alpha beta)~%    (two gamma delta)))~%")
 "(cond ((foo x) (one alpha beta) (two gamma delta)))"
 28)

(check-format
 (format nil "(case value~%  ((foo bar)~%    (one alpha beta)~%    (two gamma delta))~%  (otherwise fallback))~%")
 "(case value ((foo bar) (one alpha beta) (two gamma delta)) (otherwise fallback))"
 28)

(check-format
 (format nil "(handler-case (work)~%  (error (condition)~%    (report condition)~%    (recover)))~%")
 "(handler-case (work) (error (condition) (report condition) (recover)))"
 28)

(check-format
 (format nil "(force-evaluation~%  (evaluate-document document last base))~%")
 "(force-evaluation (evaluate-document document last base))"
 45)

(check-format
 (format nil "(if (predicate value)~%    (consequent value)~%    (alternative value))~%")
 "(if (predicate value) (consequent value) (alternative value))"
 30)

(check-format
 (format nil "(loop~%  while (ready-p item)~%  do (process item))~%")
 "(loop while (ready-p item) do (process item))"
 32)

(check-format
 (format nil "`(let ((,name ,value))~%   (etypecase ,name~%     (string ,@body)~%     (cons nil)))~%")
 "`(let ((,name ,value)) (etypecase ,name (string ,@body) (cons nil)))"
 34)

(check-format
 (format nil "#+zoot-statistics~%(defgeneric note-evaluation (evaluation))~%")
 "#+zoot-statistics (defgeneric note-evaluation (evaluation))"
 80)

(check-format
 (format nil "(let ((*cost* cost)~%      #+zoot-statistics~%      (*statistics* (make-statistics)))~%  evaluation)~%")
 "(let ((*cost* cost) #+zoot-statistics (*statistics* (make-statistics))) evaluation)"
 80)

(format t "Common Lisp S-expression printer: ~D checks passed.~%" *tests*)
