(in-package #:zoot)

;;; Descriptive document construction

(defparameter *indentation-width* 2
  "The number of columns added by INDENTED.")

(defun separated-by (separator documents)
  "Concatenate DOCUMENTS with SEPARATOR between adjacent documents."
  (if (null documents)
      (text "")
      (reduce (lambda (left right)
                (cat left separator right))
              (rest documents)
              :initial-value (first documents))))

(defun separated-by-spaces (documents)
  "Place one space between adjacent DOCUMENTS."
  (separated-by (text " ") documents))

(defun one-per-line (documents)
  "Place a hard newline between adjacent DOCUMENTS."
  (separated-by +newline+ documents))

(defun possibly-collapsed-to-one-line (document)
  "Choose between DOCUMENT and the same document with newlines flattened
to spaces. This is commonly applied to a ONE-PER-LINE construction."
  (group document))

(defun surrounded-by (opening closing document)
  "Place DOCUMENT between OPENING and CLOSING documents."
  (cat opening document closing))

(defun surrounded-by-parentheses (document)
  (surrounded-by (text "(") (text ")") document))

(defun surrounded-by-square-brackets (document)
  (surrounded-by (text "[") (text "]") document))

(defun surrounded-by-braces (document)
  (surrounded-by (text "{") (text "}") document))

(defun indented-by (amount document)
  "Indent lines after DOCUMENT's first line by AMOUNT columns."
  (nest amount document))

(defun indented (document)
  "Indent lines after DOCUMENT's first line by *INDENTATION-WIDTH*."
  (indented-by *indentation-width* document))

(defun starting-on-next-line (document)
  "Precede DOCUMENT with a hard newline."
  (cat +newline+ document))

(defun aligned-to-current-column (document)
  "Use the current output column as DOCUMENT's indentation base."
  (align document))
