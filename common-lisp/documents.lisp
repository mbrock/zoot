(in-package #:zoot)

;;; Documents
;;;
;;; Documents are plain data, as in recursive.zig: a string is a text
;;; terminal, the newline character is a hard line break, a cons is a
;;; concatenation, and small structs cover choice, indentation, and memo
;;; checkpoints.

(defconstant +initial-memo-weight+ 6
  "Number of concatenation levels between memo checkpoints, as in the OCaml
reference implementation (its PARAM_MEMO_LIMIT is 7, with initial weight 6).")

(defstruct (choice-document (:constructor %choice-document (left right)))
  (left nil :read-only t)
  (right nil :read-only t))

(defstruct (nest-document (:constructor %nest-document (amount child)))
  (amount 0 :type nonnegative-fixnum :read-only t)
  (child nil :read-only t))

(defstruct (align-document (:constructor %align-document (child)))
  (child nil :read-only t))

(defstruct (memo-document (:constructor %memo-document (child)))
  ;; Each checkpoint owns its context table for the document's lifetime.
  ;; Entries are keyed by evaluation context under one cost configuration,
  ;; so a document belongs to the configuration it is first picked with.
  (contexts (make-hash-table :test #'eq) :type hash-table :read-only t)
  (child nil :read-only t))

(defstruct (verbatim-document (:constructor %verbatim-document (text)))
  (text "" :type string :read-only t))

(defstruct (span-document (:constructor %span-document (meta child)))
  "An annotation carrying opaque META through layout to rendering. Spans
are invisible to measurement, so styling never influences the search."
  (meta nil :read-only t)
  (child nil :read-only t))

(deftype document ()
  '(or string character cons
       choice-document nest-document align-document memo-document
       verbatim-document span-document))

(defun verbatim (string)
  "A text block whose newlines are part of its content. Lines after the
first start at column zero regardless of surrounding indentation, and
the block cannot be flattened."
  (check-type string string)
  (if (find #\Newline string)
      (%verbatim-document string)
      string))

(declaim (ftype (function (t) (integer 0 #.+initial-memo-weight+))
                memo-weight next-memo-weight))

(defun memo-weight (document)
  "Structural levels below DOCUMENT until a memo checkpoint. Zero marks a
checkpoint. The countdown flows through every composite node, choices
included, so that documents sharing subtrees through choice chains still
hit checkpoints; leaves reset it. The public constructors wrap any node
whose countdown runs out, which also bounds this recursion."
  (typecase document
    (memo-document 0)
    (cons (min (next-memo-weight (car document))
               (next-memo-weight (cdr document))))
    (choice-document
     (min (next-memo-weight (choice-document-left document))
          (next-memo-weight (choice-document-right document))))
    (nest-document (next-memo-weight (nest-document-child document)))
    (align-document (next-memo-weight (align-document-child document)))
    (span-document (next-memo-weight (span-document-child document)))
    (t +initial-memo-weight+)))

(defun next-memo-weight (document)
  (let ((weight (memo-weight document)))
    (if (zerop weight) +initial-memo-weight+ (1- weight))))

(defun checkpointed (node)
  "Wrap NODE in a memo checkpoint when its countdown has run out."
  (if (zerop (memo-weight node))
      (%memo-document node)
      node))

(defun text (string)
  "A terminal document. STRING must not contain a newline."
  (check-type string string)
  (when (find #\Newline string)
    (error "TEXT terminals cannot contain newlines: ~S" string))
  string)

(defconstant +newline+ #\Newline
  "A hard newline. Its following indentation is determined by NEST and ALIGN.")

(defun concatenate (left right)
  "Unaligned concatenation: place RIGHT immediately after LEFT."
  (checkpointed (cons left right)))

(defun choice (left right)
  "An arbitrary choice between two documents."
  (checkpointed (%choice-document left right)))

(defun nest (amount document)
  "Indent lines after the first by AMOUNT columns."
  (check-type amount nonnegative-fixnum)
  (if (zerop amount)
      document
      (checkpointed (%nest-document amount document))))

(defun align (document)
  "Use the current column as DOCUMENT's indentation base."
  (checkpointed (%align-document document)))

(defun span (meta document)
  "Annotate DOCUMENT with opaque META, interpreted by RENDER-LAYOUT
methods specialized on the output stream and transparent otherwise.
Spans take no columns and cost nothing, so they cannot influence
layout choice."
  (checkpointed (%span-document meta document)))

(defun cat (&rest documents)
  (reduce #'concatenate documents :initial-value (text "")))

(defun vcat (&rest documents)
  (if (null documents)
      (text "")
      (reduce (lambda (left right)
                (concatenate (concatenate left +newline+) right))
              (rest documents)
              :initial-value (first documents))))

(defun flatten (document)
  "Replace newlines with spaces and recursively flatten both choice
branches. Memo checkpoints are preserved in place, so the flattened
document needs no reweighting."
  (etypecase document
    (string document)
    (character " ")
    (verbatim-document document)
    (cons (cons (flatten (car document)) (flatten (cdr document))))
    (memo-document (%memo-document (flatten (memo-document-child document))))
    (choice-document
     (%choice-document (flatten (choice-document-left document))
                       (flatten (choice-document-right document))))
    (nest-document (flatten (nest-document-child document)))
    (align-document
     (%align-document (flatten (align-document-child document))))
    (span-document
     (%span-document (span-document-meta document)
                     (flatten (span-document-child document))))))

(defun group (document)
  "Choose between DOCUMENT and its flattened form."
  (choice document (flatten document)))
