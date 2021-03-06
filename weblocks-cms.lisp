;;;; weblocks-cms.lisp

(in-package #:weblocks-cms)

;;; Hacks and glory await!

(defwebapp weblocks-cms
           :prefix "/super-admin"
           :description "Weblocks CMS"
           :init-user-session 'init-super-admin-session
           :subclasses (weblocks-twitter-bootstrap-application:twitter-bootstrap-webapp)
           :autostart nil                   ;; have to start the app manually
           :ignore-default-dependencies nil ;; accept the defaults
           :js-backend :jquery
           :debug t)

(defvar *additional-schemes* nil 
  "Additional schemes are not writen to schema file and used by Weblocks CMS plugins")

(defmethod get-model-form-view-fields (model)
  "Returns form view fields list for model. Model is a keyword"
  (let ((description (get-model-description model)))
    (loop for j in (getf description :fields) 
          append (get-view-fields-for-field-description j description))))

(defun get-model-form-view (model &key (display-buttons t))
  "Returns form view for model. Model is a keyword. View is used in model grid."
  (let ((description (get-model-description model)))
    (eval 
      `(defview nil (:type form-with-refresh-button 
                           :caption ,(getf description :title)
                           :inherit-from ',(list :scaffold (keyword->symbol (getf description :name)))
                           :enctype "multipart/form-data"
                           :use-ajax-p t
                           ,@(if display-buttons 
                               (list :buttons (quote '((:submit . "Save & Close") (:update . "Save & Edit") (:cancel . "Close Without Saving"))))
                               (list :buttons nil)))
                ,@(get-model-form-view-fields model)))))

(defmethod get-model-table-view-fields (obj)
  "Returns table view fields list for model. Model is a keyword"
  (let ((description (get-model-description obj)))
    (loop for j in (getf description :fields) 
          append (get-table-view-fields-for-field-description j description))))

(defun get-model-table-view (model)
  "Returns table view for model. Model is a keyword. View is used in model grid."
  (let ((description (get-model-description model)))
    (eval 
      `(defview nil (:type table 
                     :inherit-from ',(list :scaffold (keyword->symbol (getf description :name))))
                ,@(get-model-table-view-fields model)))))

(defun maybe-create-class-db-data (description)
  "Creates records for class and its fields information if it does not exist"
  (if weblocks-stores:*default-store*
    (let ((model-descr 
            (or (first-by-values 'model-description :name (getf description :name))
                (persist-object weblocks-stores:*default-store* 
                                (make-instance 'model-description :name (getf description :name) :title (getf description :title))))))
      (loop for i in (getf description :fields)
            do (or (first-by-values 'field-description 
                                    :model model-descr 
                                    :name (getf i :name))
                   (persist-object 
                     weblocks-stores:*default-store* 
                     (make-instance 'field-description 
                                    :name (getf i :name)
                                    :title (getf i :title)
                                    :type (getf i :type)
                                    :type-data (or (getf i :type-data) (getf i :options))
                                    :model model-descr)))))
    (warn "Description db data not generated for class ~A, store is not yet opened" (getf description :name))))

(defmethod model-class-from-description (store-type i)
  (eval
    `(defclass ,(keyword->symbol (getf i :name)) ()
       ((,(keyword->symbol :id))
        ,@(loop for j in (getf i :fields) collect 
                (append 
                  (list 
                    (keyword->symbol (getf j :name))

                    :initarg (alexandria:make-keyword (string-upcase (getf j :name)))
                    :initform nil
                    :accessor (intern (string-upcase (format nil "~A-~A" (getf i :name)  (getf j :name))) *models-package*))
                  (cond 
                    ((find (getf j :type) (list :string :integer))
                     (list :type (intern (string-upcase (getf j :type)))))
                    (t nil))))))))

(defmethod model-class-from-description ((store-type (eql :perec)) i)
  (eval
    `(,(intern "DEFPCLASS" :hu.dwim.perec) ,(keyword->symbol (getf i :name)) ()
       (,@(loop for j in (getf i :fields) collect 
                (append 
                  (list 
                    (keyword->symbol (getf j :name))

                    :initarg (alexandria:make-keyword (string-upcase (getf j :name)))
                    :initform nil
                    :accessor (intern (string-upcase (format nil "~A-~A" (getf i :name)  (getf j :name))) *models-package*))
                  (cond 
                    ((find (getf j :type) (list :string :integer))
                     (list :type `(or 
                                    null 
                                    ,(intern (string-upcase (getf j :type))
                                             (find-package :hu.dwim.perec)))))
                    ((equal (getf j :type) :textarea)
                     (list :type `(or 
                                    null
                                    (intern 
                                      "TEXT"
                                      (find-package :hu.dwim.perec)))))
                    (t (list :type `(or 
                                      null
                                      ,(intern 
                                         "SERIALIZED" 
                                         (find-package :hu.dwim.perec))))))))))))

(defvar *store-type* nil)

(defun generate-model-class-from-description (i)
  "Creates CLOS class by schema class description list"
  (model-class-from-description *store-type* i))

(defun available-schemes-data (&optional (schema *current-schema*))
  (apply #'append (list* schema (mapcar #'cdr *additional-schemes*))))

(defun regenerate-model-classes (&optional (schema *current-schema*))
  "Transforms schema description to classes"

  (generate-model-class-from-description 
    '(:TITLE "Doesn't matter" :NAME :MODEL-DESCRIPTION 
      :FIELDS ((:TITLE "Doesn't matter" :NAME :NAME :TYPE :CUSTOM :OPTIONS NIL)
               (:TITLE "Doesn't matter" :NAME :TITLE :TYPE :CUSTOM :OPTIONS NIL))))
  (generate-model-class-from-description 
    '(:TITLE "Doesn't matter" :NAME :FIELD-DESCRIPTION 
      :FIELDS ((:TITLE "Doesn't matter" :NAME :NAME :TYPE :CUSTOM :OPTIONS NIL)
               (:TITLE "Doesn't matter" :NAME :TITLE :TYPE :CUSTOM :OPTIONS NIL)
               (:TITLE "Doesn't matter" :NAME :TYPE :TYPE :CUSTOM :OPTIONS NIL)
               (:TITLE "Doesn't matter" :NAME :TYPE-DATA :TYPE :CUSTOM :OPTIONS NIL)
               (:TITLE "Doesn't matter" :NAME :MODEL :TYPE :SINGLE-CHOICE :OPTIONS NIL))))

  (loop for i in (available-schemes-data schema) do
        (generate-model-class-from-description i)
        (maybe-create-class-db-data i)))

(defun refresh-schema()
  (setf *current-schema* (read-schema))
  (regenerate-model-classes))

(defun get-view-fields-for-field-description (i model-description-list)
  (get-view-fields-for-field-type-and-description (getf i :type) i model-description-list))

(defun get-table-view-fields-for-field-description (i model-description-list)
  (get-table-view-fields-for-field-type-and-description (getf i :type) i model-description-list))

(defun make-gridedit-page-for-model-description (i)
  (let* ((grid (make-instance 
                 'popover-gridedit 
                 :data-class (keyword->symbol (getf i :name))
                 :item-form-view (get-model-form-view (getf i :name))
                 :view (get-model-table-view (getf i :name))))
         (filtering-widget (when 
                             (find-package 'weblocks-filtering-widget)
                             (make-instance 
                               (intern "FILTERING-WIDGET" "WEBLOCKS-FILTERING-WIDGET") 
                               :dataseq-instance grid
                               :filter-form-visible nil
                               :form-fields (funcall (symbol-function (intern "ALL-FILTERS-FOR-MODEL" "WEBLOCKS-FILTERING-WIDGET")) (keyword->symbol (getf i :name)))))))

    (when (find-package 'weblocks-filtering-widget)
      (funcall (symbol-function (intern "HIDE-FILTER-FORM" "WEBLOCKS-FILTERING-WIDGET")) filtering-widget))

    (make-instance 
      'weblocks:composite
      :widgets (remove-if #'null (list filtering-widget grid)))))

(defun make-tree-edit-for-model-description (i)
  (let* ((model-class (keyword->symbol (getf i :name)))
         (grid)
         (view (get-model-form-view (getf i :name))))
    (setf grid (make-instance 'tree-edit 
                              :item-form-view (get-model-form-view (getf i :name))
                              :view (defview nil (:type tree)
                                             (data 
                                               :label "Tree"
                                               :present-as tree-branches 
                                               :reader (lambda (item)
                                                         (if (typep item model-class)
                                                           (tree-item-title item)
                                                           (tree-item-title (getf item :item)))))
                                             (action-links 
                                               :label "Actions"
                                               :present-as html 
                                               :reader (lambda (item)
                                                         (funcall (action-links-reader grid view) item))))
                              :data-class model-class))
    grid))

(defun description-of-a-tree-p (model-description)
  (loop for i in (getf model-description :fields) do 
        (when (and 
                (equal (getf i :name) :parent)
                (equal (getf i :type) :single-relation))
          (return-from description-of-a-tree-p t))))

(defmethod make-widget-for-model-description (name description)
  (funcall 
    (if (description-of-a-tree-p description)
      #'make-tree-edit-for-model-description
      #'make-gridedit-page-for-model-description) description))

(defun models-gridedit-widgets-for-navigation ()
  (loop for i in (available-schemes-data) collect 
        (list 
          (getf i :title)
          (make-widget-for-model-description (getf i :name) i)
          
          (string-downcase (getf i :name)))))

(defvar *admin-menu-widgets* nil 
  "Contains list of menu items, each menu item is either a list of title/widget/name for navigation or a callback which should return title/widget/name")

(defun weblocks-cms-admin-menu ()
  (append 
    (models-gridedit-widgets-for-navigation)
    (loop for i in *admin-menu-widgets* 
          collect (if (functionp i)
                    (funcall i)
                    i))))

(defun def-additional-schema (name schema)
  (setf *additional-schemes* 
        (remove-if 
          (lambda (item)
            (equal (car item) name))
          *additional-schemes*))
  (push (cons name schema) *additional-schemes*)
  (mapcar #'generate-model-class-from-description schema))

(defun import-model-symbols (template)
  (import (intern (string-upcase template) "WEBLOCKS-CMS") *package*))
