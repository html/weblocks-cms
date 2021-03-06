(in-package :weblocks-cms)

(defwidget tree-edit (tree-widget)
  ()
  (:default-initargs 
    :allow-pagination-p nil 
    :allow-delete-p nil 
    :allow-select-p nil 
    :allow-operations-p t))

(defun tree-item-children (cls)
  (let ((func)
        (model-description (loop for i in (available-schemes-data) 
                                 if (equal 
                                      (keyword->symbol (getf i :name))
                                      cls)
                                 return i))
        (relation))

    (setf relation 
          (loop for i in (getf model-description :fields) 
                if (equal (getf i :type) :single-relation)
                return i))

    (setf func 
          (lambda (obj) 
            (loop for i in (find-by-values cls (getf relation :name) obj) collect 
                  (list :item i 
                        :children func))))
    (funcall func nil)))

(defmethod weblocks-tree-widget:tree-data ((obj tree-edit))
  (tree-item-children (dataseq-data-class obj)))
