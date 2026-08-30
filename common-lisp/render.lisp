(in-package #:zoot)

;;; Rendering

(defgeneric render-layout (document stream last base)
  (:documentation
   "Write DOCUMENT at column LAST with indentation base BASE, returning
the column after it. Rendering is the open part of the evaluator:
methods on new document kinds extend output without touching layout
search."))

(defmethod render-layout ((document string) stream last base)
  (declare (ignore base) (type nonnegative-fixnum last))
  (write-string document stream)
  (the nonnegative-fixnum (+ last (length document))))

(defmethod render-layout ((document verbatim-document) stream last base)
  (declare (ignore base) (type nonnegative-fixnum last))
  (let* ((string (verbatim-document-text document))
         (break (position #\Newline string :from-end t)))
    (write-string string stream)
    (the nonnegative-fixnum
         (if break
             (- (length string) break 1)
             (+ last (length string))))))

(defmethod render-layout ((document character) stream last base)
  (declare (ignore last) (type nonnegative-fixnum base))
  (terpri stream)
  (loop repeat base do (write-char #\Space stream))
  base)

(defmethod render-layout ((document cons) stream last base)
  (declare (type nonnegative-fixnum last base))
  (render-layout (cdr document) stream
                 (render-layout (car document) stream last base)
                 base))

(defmethod render-layout ((document nest-document) stream last base)
  (declare (type nonnegative-fixnum last base))
  (render-layout (nest-document-child document) stream last
                 (the nonnegative-fixnum
                      (+ base (nest-document-amount document)))))

(defmethod render-layout ((document align-document) stream last base)
  (declare (ignore base) (type nonnegative-fixnum last))
  (render-layout (align-document-child document) stream last last))

(defmethod render-layout ((document memo-document) stream last base)
  (render-layout (memo-document-child document) stream last base))

;; Spans are transparent by default. A stream that interprets
;; annotations specializes this method and wraps CALL-NEXT-METHOD.
(defmethod render-layout ((document span-document) stream last base)
  (render-layout (span-document-child document) stream last base))

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
