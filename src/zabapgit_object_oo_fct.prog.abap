"This interface contains SAP object oriented functions that can't be put under test
"(i.e. creating a Class in the system)
INTERFACE lif_object_oriented_object_fnc.
  TYPES: BEGIN OF ty_includes,
           programm TYPE programm,
         END OF ty_includes,
         ty_includes_tt TYPE STANDARD TABLE OF ty_includes WITH DEFAULT KEY.

  METHODS:
    create
      IMPORTING
        iv_package    TYPE devclass
        iv_overwrite  TYPE seox_boolean DEFAULT seox_true
      CHANGING
        is_properties TYPE any
      RAISING
        lcx_exception,
    generate_locals
      IMPORTING
        is_key                   TYPE seoclskey
        iv_force                 TYPE seox_boolean DEFAULT seox_true
        it_local_definitions     TYPE seop_source_string OPTIONAL
        it_local_implementations TYPE seop_source_string OPTIONAL
        it_local_macros          TYPE seop_source_string OPTIONAL
        it_local_test_classes    TYPE seop_source_string OPTIONAL
      RAISING
        lcx_exception,
    deserialize_source
      IMPORTING
        is_key    TYPE seoclskey
        it_source TYPE ty_string_tt
      RAISING
        lcx_exception
        cx_sy_dyn_call_error,
    insert_text_pool
      IMPORTING
        iv_class_name TYPE seoclsname
        it_text_pool  TYPE textpool_table
        iv_language   TYPE spras
      RAISING
        lcx_exception,
    update_descriptions
      IMPORTING
        is_key          TYPE seoclskey
        it_descriptions TYPE ty_seocompotx_tt,
    add_to_activation_list
      IMPORTING
        is_item TYPE ty_item
      RAISING
        lcx_exception,
    create_sotr
      IMPORTING
        iv_package TYPE devclass
        it_sotr    TYPE ty_sotr_tt
      RAISING
        lcx_exception,
    create_documentation
      IMPORTING
        it_lines       TYPE tlinetab
        iv_object_name TYPE dokhl-object
        iv_language    TYPE spras
      RAISING
        lcx_exception,
    get_includes
      IMPORTING
        iv_object_name     TYPE sobj_name
      RETURNING
        VALUE(rt_includes) TYPE ty_includes_tt,
    exists
      IMPORTING
        iv_object_name   TYPE seoclskey
      RETURNING
        VALUE(rv_exists) TYPE abap_bool,
    serialize_abap
      IMPORTING
        is_class_key     TYPE seoclskey
        iv_type          TYPE seop_include_ext_app OPTIONAL
      RETURNING
        VALUE(rt_source) TYPE ty_string_tt
      RAISING
        lcx_exception
        cx_sy_dyn_call_error,
    get_skip_test_classes
      RETURNING
        VALUE(rv_skip) TYPE abap_bool,
    get_class_properties
      IMPORTING
        is_class_key               TYPE seoclskey
      RETURNING
        VALUE(rs_class_properties) TYPE vseoclass
      RAISING
        lcx_exception,
    get_interface_properties
      IMPORTING
        is_interface_key               TYPE seoclskey
      RETURNING
        VALUE(rs_interface_properties) TYPE vseointerf
      RAISING
        lcx_exception,
    read_text_pool
      IMPORTING
        iv_class_name       TYPE seoclsname
        iv_language         TYPE spras
      RETURNING
        VALUE(rt_text_pool) TYPE textpool_table,
    read_documentation
      IMPORTING
        iv_class_name   TYPE seoclsname
        iv_language     TYPE spras
      RETURNING
        VALUE(rt_lines) TYPE tlinetab,
    read_sotr
      IMPORTING
        iv_object_name TYPE sobj_name
      RETURNING
        VALUE(rt_sotr) TYPE ty_sotr_tt
      RAISING
        lcx_exception,
    read_descriptions
      IMPORTING
        iv_obejct_name         TYPE seoclsname
      RETURNING
        VALUE(rt_descriptions) TYPE ty_seocompotx_tt,
    delete
      IMPORTING
        is_deletion_key TYPE seoclskey
      RAISING
        lcx_exception.
ENDINTERFACE.

CLASS lcl_oo_object_serializer DEFINITION.
  PUBLIC SECTION.

    METHODS:
      serialize_abap_clif_source
        IMPORTING
          is_class_key     TYPE seoclskey
          iv_type          TYPE seop_include_ext_app OPTIONAL
        RETURNING
          VALUE(rt_source) TYPE ty_string_tt
        RAISING
          lcx_exception
          cx_sy_dyn_call_error,
      are_test_classes_skipped
        RETURNING
          VALUE(rv_return) TYPE abap_bool.
    METHODS serialize_locals_imp
      IMPORTING is_clskey        TYPE seoclskey
      RETURNING VALUE(rt_source) TYPE ty_string_tt
      RAISING   lcx_exception.

    METHODS serialize_locals_def
      IMPORTING is_clskey        TYPE seoclskey
      RETURNING VALUE(rt_source) TYPE ty_string_tt
      RAISING   lcx_exception.
    METHODS serialize_testclasses
      IMPORTING
                is_clskey        TYPE seoclskey
      RETURNING VALUE(rt_source) TYPE ty_string_tt
      RAISING   lcx_exception.

    METHODS serialize_macros
      IMPORTING is_clskey        TYPE seoclskey
      RETURNING VALUE(rt_source) TYPE ty_string_tt
      RAISING   lcx_exception.
  PRIVATE SECTION.
    DATA mv_skip_testclass TYPE abap_bool.
    METHODS serialize_abap_old
      IMPORTING is_clskey        TYPE seoclskey
      RETURNING VALUE(rt_source) TYPE ty_string_tt
      RAISING   lcx_exception.

    METHODS serialize_abap_new
      IMPORTING is_clskey        TYPE seoclskey
      RETURNING VALUE(rt_source) TYPE ty_string_tt
      RAISING   lcx_exception
                cx_sy_dyn_call_error.
    METHODS remove_signatures
      CHANGING ct_source TYPE ty_string_tt.

    METHODS read_include
      IMPORTING is_clskey        TYPE seoclskey
                iv_type          TYPE seop_include_ext_app
      RETURNING VALUE(rt_source) TYPE seop_source_string.


    METHODS reduce
      CHANGING ct_source TYPE ty_string_tt.
ENDCLASS.

CLASS lcl_oo_object_serializer IMPLEMENTATION.
  METHOD serialize_abap_clif_source.
    TRY.
        rt_source = serialize_abap_new( is_class_key ).
      CATCH cx_sy_dyn_call_error.
        rt_source = serialize_abap_old( is_class_key ).
    ENDTRY.
  ENDMETHOD.
  METHOD serialize_abap_old.
* for old ABAP AS versions
    DATA: lo_source TYPE REF TO cl_oo_source.

    CREATE OBJECT lo_source
      EXPORTING
        clskey             = is_clskey
      EXCEPTIONS
        class_not_existing = 1
        OTHERS             = 2.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'error from CL_OO_SOURCE' ).
    ENDIF.

    lo_source->read( 'A' ).
    rt_source = lo_source->get_old_source( ).
    remove_signatures( CHANGING ct_source = rt_source ).

  ENDMETHOD.                    "serialize_abap

  METHOD serialize_abap_new.

    DATA: lo_source   TYPE REF TO object,
          lo_instance TYPE REF TO object.

* do not call the class/methods statically, as it will
* give syntax errors on old versions
    CALL METHOD ('CL_OO_FACTORY')=>('CREATE_INSTANCE')
      RECEIVING
        result = lo_instance.

    CALL METHOD lo_instance->('CREATE_CLIF_SOURCE')
      EXPORTING
        clif_name = is_clskey-clsname
        version   = 'A'
      RECEIVING
        result    = lo_source.

    CALL METHOD lo_source->('GET_SOURCE')
      IMPORTING
        source = rt_source.

  ENDMETHOD.

  METHOD remove_signatures.

* signatures messes up in CL_OO_SOURCE when deserializing and serializing
* within same session

    DATA: lv_begin  TYPE string,
          lv_end    TYPE string,
          lv_remove TYPE sap_bool,
          lv_source LIKE LINE OF ct_source.

    "@TODO: Put under test
    CONCATENATE '* <SIGNATURE>------------------------------------'
      '---------------------------------------------------+'
      INTO lv_begin.

    CONCATENATE '* +------------------------------------------------'
      '--------------------------------------</SIGNATURE>'
      INTO lv_end.

    lv_remove = abap_false.
    LOOP AT ct_source INTO lv_source.
      IF lv_source = lv_begin.
        lv_remove = abap_true.
      ENDIF.
      IF lv_remove = abap_true.
        DELETE ct_source INDEX sy-tabix.
      ENDIF.
      IF lv_source = lv_end.
        lv_remove = abap_false.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.                    "remove_signatures
  METHOD reduce.

    DATA: lv_source LIKE LINE OF ct_source,
          lv_found  TYPE sap_bool.


* skip files that only contain the standard comments
    lv_found = abap_false.
    LOOP AT ct_source INTO lv_source.
      IF strlen( lv_source ) >= 3 AND lv_source(3) <> '*"*'.
        lv_found = abap_true.
      ENDIF.
    ENDLOOP.
    IF lv_found = abap_false.
      CLEAR ct_source[].
    ENDIF.

  ENDMETHOD.                    "reduce

  METHOD serialize_locals_imp.

    rt_source = read_include( is_clskey = is_clskey
                              iv_type = seop_ext_class_locals_imp ).

    reduce( CHANGING ct_source = rt_source ).

  ENDMETHOD.                    "serialize_local

  METHOD serialize_locals_def.

    rt_source = read_include( is_clskey = is_clskey
                              iv_type = seop_ext_class_locals_def ).

    reduce( CHANGING ct_source = rt_source ).

  ENDMETHOD.                    "serialize_locals_def

  METHOD read_include.

    DATA: ls_include TYPE progstruc.


    ASSERT iv_type = seop_ext_class_locals_def
      OR iv_type = seop_ext_class_locals_imp
      OR iv_type = seop_ext_class_macros
      OR iv_type = seop_ext_class_testclasses.

    ls_include-rootname = is_clskey-clsname.
    TRANSLATE ls_include-rootname USING ' ='.
    ls_include-categorya = iv_type(1).
    ls_include-codea = iv_type+1(4).

* it looks like there is an issue in function module SEO_CLASS_GET_INCLUDE_SOURCE
* on 750 kernels, where the READ REPORT without STATE addition does not
* return the active version, this method is a workaround for this issue
    READ REPORT ls_include INTO rt_source STATE 'A'.

  ENDMETHOD.

  METHOD serialize_testclasses.

    DATA: lv_line1 LIKE LINE OF rt_source,
          lv_line2 LIKE LINE OF rt_source.


    rt_source = read_include( is_clskey = is_clskey
                              iv_type = seop_ext_class_testclasses ).

* when creating classes in Eclipse it automatically generates the
* testclass include, but it is not needed, so skip to avoid
* creating an extra file in the repository.
* Also remove it if the content is manually removed, but
* the class still thinks it contains tests
    "@TODO: Put under test
    mv_skip_testclass = abap_false.
    IF lines( rt_source ) = 2.
      READ TABLE rt_source INDEX 1 INTO lv_line1.
      ASSERT sy-subrc = 0.
      READ TABLE rt_source INDEX 2 INTO lv_line2.
      ASSERT sy-subrc = 0.
      IF lv_line1(3) = '*"*' AND lv_line2 IS INITIAL.
        mv_skip_testclass = abap_true.
      ENDIF.
    ELSEIF lines( rt_source ) = 1.
      READ TABLE rt_source INDEX 1 INTO lv_line1.
      ASSERT sy-subrc = 0.
      IF lv_line1 IS INITIAL
          OR ( strlen( lv_line1 ) >= 3 AND lv_line1(3) = '*"*' )
          OR ( strlen( lv_line1 ) = 1 AND lv_line1(1) = '*' ).
        mv_skip_testclass = abap_true.
      ENDIF.
    ELSEIF lines( rt_source ) = 0.
      mv_skip_testclass = abap_true.
    ENDIF.

  ENDMETHOD.                    "serialize_test

  METHOD serialize_macros.

    rt_source = read_include( is_clskey = is_clskey
                              iv_type = seop_ext_class_macros ).

    reduce( CHANGING ct_source = rt_source ).

  ENDMETHOD.                    "serialize_macro
  METHOD are_test_classes_skipped.
    rv_return = mv_skip_testclass.
  ENDMETHOD.

ENDCLASS.

CLASS lcl_object_oriented_base DEFINITION ABSTRACT.
  PUBLIC SECTION.
    INTERFACES: lif_object_oriented_object_fnc.
  PRIVATE SECTION.
    DATA mv_skip_test_classes TYPE abap_bool.
    METHODS deserialize_abap_source_old
      IMPORTING is_clskey TYPE seoclskey
                it_source TYPE ty_string_tt
      RAISING   lcx_exception.

    METHODS deserialize_abap_source_new
      IMPORTING is_clskey TYPE seoclskey
                it_source TYPE ty_string_tt
      RAISING   lcx_exception
                cx_sy_dyn_call_error.
ENDCLASS.

CLASS lcl_object_oriented_base IMPLEMENTATION.

  METHOD lif_object_oriented_object_fnc~create.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~deserialize_source.
    TRY.
        deserialize_abap_source_new(
          is_clskey = is_key
          it_source = it_source ).
      CATCH cx_sy_dyn_call_error.
        deserialize_abap_source_old(
          is_clskey = is_key
          it_source = it_source ).
    ENDTRY.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~generate_locals.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD deserialize_abap_source_old.
    "for backwards compatability down to 702

    DATA: lo_source TYPE REF TO cl_oo_source.

    CREATE OBJECT lo_source
      EXPORTING
        clskey             = is_clskey
      EXCEPTIONS
        class_not_existing = 1
        OTHERS             = 2.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'error from CL_OO_SOURCE' ).
    ENDIF.

    TRY.
        lo_source->access_permission( seok_access_modify ).
        lo_source->set_source( it_source ).
        lo_source->save( ).
        lo_source->access_permission( seok_access_free ).
      CATCH cx_oo_access_permission.
        lcx_exception=>raise( 'permission error' ).
      CATCH cx_oo_source_save_failure.
        lcx_exception=>raise( 'save failure' ).
    ENDTRY.

  ENDMETHOD.

  METHOD deserialize_abap_source_new.
    DATA: lo_factory TYPE REF TO object,
          lo_source  TYPE REF TO object.

    CALL METHOD ('CL_OO_FACTORY')=>('CREATE_INSTANCE')
      RECEIVING
        result = lo_factory.

    CALL METHOD lo_factory->('CREATE_CLIF_SOURCE')
      EXPORTING
        clif_name = is_clskey-clsname
      RECEIVING
        result    = lo_source.

    TRY.
        CALL METHOD lo_source->('IF_OO_CLIF_SOURCE~LOCK').
      CATCH cx_oo_access_permission.
        lcx_exception=>raise( 'source_new, access permission exception' ).
    ENDTRY.

    CALL METHOD lo_source->('IF_OO_CLIF_SOURCE~SET_SOURCE')
      EXPORTING
        source = it_source.

    CALL METHOD lo_source->('IF_OO_CLIF_SOURCE~SAVE').

    CALL METHOD lo_source->('IF_OO_CLIF_SOURCE~UNLOCK').

  ENDMETHOD.
  METHOD lif_object_oriented_object_fnc~add_to_activation_list.
    lcl_objects_activation=>add_item( is_item ).
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~update_descriptions.
    DELETE FROM seocompotx WHERE clsname = is_key-clsname.
    INSERT seocompotx FROM TABLE it_descriptions.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~insert_text_pool.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~create_sotr.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~create_documentation.
    CALL FUNCTION 'DOCU_UPD'
      EXPORTING
        id       = 'CL'
        langu    = iv_language
        object   = iv_object_name
      TABLES
        line     = it_lines
      EXCEPTIONS
        ret_code = 1
        OTHERS   = 2.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'error from DOCU_UPD' ).
    ENDIF.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~get_includes.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~exists.
    CALL FUNCTION 'SEO_CLASS_EXISTENCE_CHECK'
      EXPORTING
        clskey        = iv_object_name
      EXCEPTIONS
        not_specified = 1
        not_existing  = 2
        is_interface  = 3
        no_text       = 4
        inconsistent  = 5
        OTHERS        = 6.
    rv_exists = boolc( sy-subrc <> 2 ).
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~serialize_abap.
    DATA lo_oo_serializer TYPE REF TO lcl_oo_object_serializer.
    CREATE OBJECT lo_oo_serializer.
    CASE iv_type.
      WHEN seop_ext_class_locals_def.
        rt_source = lo_oo_serializer->serialize_locals_def( is_class_key ).
      WHEN seop_ext_class_locals_imp.
        rt_source = lo_oo_serializer->serialize_locals_imp( is_class_key ).
      WHEN seop_ext_class_macros.
        rt_source = lo_oo_serializer->serialize_macros( is_class_key ).
      WHEN seop_ext_class_testclasses.
        rt_source = lo_oo_serializer->serialize_testclasses( is_class_key ).
        mv_skip_test_classes = lo_oo_serializer->are_test_classes_skipped( ).
      WHEN OTHERS.
        rt_source = lo_oo_serializer->serialize_abap_clif_source( is_class_key ).
    ENDCASE.
  ENDMETHOD.
  METHOD lif_object_oriented_object_fnc~get_skip_test_classes.
    rv_skip = mv_skip_test_classes.
  ENDMETHOD.
  METHOD lif_object_oriented_object_fnc~get_class_properties.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~get_interface_properties.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~read_text_pool.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~read_sotr.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~read_documentation.
    DATA:
      lv_state  TYPE dokstate,
      lv_object TYPE dokhl-object,
      lt_lines  TYPE tlinetab.

    lv_object = iv_class_name.

    CALL FUNCTION 'DOCU_GET'
      EXPORTING
        id                = 'CL'
        langu             = iv_language
        object            = lv_object
      IMPORTING
        dokstate          = lv_state
      TABLES
        line              = lt_lines
      EXCEPTIONS
        no_docu_on_screen = 1
        no_docu_self_def  = 2
        no_docu_temp      = 3
        ret_code          = 4
        OTHERS            = 5.
    IF sy-subrc = 0 AND lv_state = 'R'.
      rt_lines = lt_lines.
    ELSE.
      CLEAR rt_lines.
    ENDIF.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~read_descriptions.
    SELECT * FROM seocompotx INTO TABLE rt_descriptions
      WHERE clsname = iv_obejct_name.
    DELETE rt_descriptions WHERE descript IS INITIAL.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~delete.
    ASSERT 0 = 1. "Subclass responsibility
  ENDMETHOD.

ENDCLASS.



CLASS lcl_object_oriented_class DEFINITION
  INHERITING FROM lcl_object_oriented_base.
  PUBLIC SECTION.
    METHODS:
      lif_object_oriented_object_fnc~create REDEFINITION,
      lif_object_oriented_object_fnc~generate_locals REDEFINITION,
      lif_object_oriented_object_fnc~insert_text_pool REDEFINITION,
      lif_object_oriented_object_fnc~create_sotr REDEFINITION,
      lif_object_oriented_object_fnc~get_includes REDEFINITION,
      lif_object_oriented_object_fnc~get_class_properties REDEFINITION,
      lif_object_oriented_object_fnc~read_text_pool REDEFINITION,
      lif_object_oriented_object_fnc~read_sotr REDEFINITION,
      lif_object_oriented_object_fnc~delete REDEFINITION.

ENDCLASS.
CLASS lcl_object_oriented_class IMPLEMENTATION.
  METHOD lif_object_oriented_object_fnc~create.
    CALL FUNCTION 'SEO_CLASS_CREATE_COMPLETE'
      EXPORTING
        devclass        = iv_package
        overwrite       = iv_overwrite
      CHANGING
        class           = is_properties
      EXCEPTIONS
        existing        = 1
        is_interface    = 2
        db_error        = 3
        component_error = 4
        no_access       = 5
        other           = 6
        OTHERS          = 7.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'error from SEO_CLASS_CREATE_COMPLETE' ).
    ENDIF.
  ENDMETHOD.
  METHOD lif_object_oriented_object_fnc~generate_locals.
    CALL FUNCTION 'SEO_CLASS_GENERATE_LOCALS'
      EXPORTING
        clskey                 = is_key
        force                  = iv_force
        locals_def             = it_local_definitions
        locals_imp             = it_local_implementations
        locals_mac             = it_local_macros
        locals_testclasses     = it_local_test_classes
      EXCEPTIONS
        not_existing           = 1
        model_only             = 2
        locals_not_generated   = 3
        locals_not_initialised = 4
        OTHERS                 = 5.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'error from generate_locals' ).
    ENDIF.
  ENDMETHOD.
  METHOD lif_object_oriented_object_fnc~insert_text_pool.
    DATA: lv_cp        TYPE program.

    lv_cp = cl_oo_classname_service=>get_classpool_name( iv_class_name ).

    INSERT TEXTPOOL lv_cp
      FROM it_text_pool
      LANGUAGE iv_language
      STATE 'I'.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'error from INSERT TEXTPOOL' ).
    ENDIF.

    lcl_objects_activation=>add( iv_type = 'REPT'
                                 iv_name = lv_cp ).
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~create_sotr.
    DATA: lt_sotr    TYPE ty_sotr_tt,
          lt_objects TYPE sotr_objects,
          ls_paket   TYPE sotr_pack,
          lv_object  LIKE LINE OF lt_objects.

    FIELD-SYMBOLS: <ls_sotr> LIKE LINE OF lt_sotr.

    LOOP AT it_sotr ASSIGNING <ls_sotr>.
      CALL FUNCTION 'SOTR_OBJECT_GET_OBJECTS'
        EXPORTING
          object_vector    = <ls_sotr>-header-objid_vec
        IMPORTING
          objects          = lt_objects
        EXCEPTIONS
          object_not_found = 1
          OTHERS           = 2.
      IF sy-subrc <> 0.
        lcx_exception=>raise( 'error from SOTR_OBJECT_GET_OBJECTS' ).
      ENDIF.

      READ TABLE lt_objects INDEX 1 INTO lv_object.
      ASSERT sy-subrc = 0.

      ls_paket-paket = iv_package.

      CALL FUNCTION 'SOTR_CREATE_CONCEPT'
        EXPORTING
          paket                         = ls_paket
          crea_lan                      = <ls_sotr>-header-crea_lan
          alias_name                    = <ls_sotr>-header-alias_name
          object                        = lv_object
          entries                       = <ls_sotr>-entries
          concept_default               = <ls_sotr>-header-concept
        EXCEPTIONS
          package_missing               = 1
          crea_lan_missing              = 2
          object_missing                = 3
          paket_does_not_exist          = 4
          alias_already_exist           = 5
          object_type_not_found         = 6
          langu_missing                 = 7
          identical_context_not_allowed = 8
          text_too_long                 = 9
          error_in_update               = 10
          no_master_langu               = 11
          error_in_concept_id           = 12
          alias_not_allowed             = 13
          tadir_entry_creation_failed   = 14
          internal_error                = 15
          error_in_correction           = 16
          user_cancelled                = 17
          no_entry_found                = 18
          OTHERS                        = 19.
      IF sy-subrc <> 0.
        lcx_exception=>raise( 'error from SOTR_CREATE_CONCEPT' ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~get_includes.
* note: includes returned might not exist
* method cl_oo_classname_service=>GET_ALL_CLASS_INCLUDES does not exist in 702

    DATA: lv_class_name TYPE seoclsname,
          lt_methods    TYPE seop_methods_w_include.

    FIELD-SYMBOLS: <ls_method> LIKE LINE OF lt_methods.

    lv_class_name = iv_object_name.

    APPEND cl_oo_classname_service=>get_ccdef_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_ccmac_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_ccimp_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_cl_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_ccau_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_pubsec_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_prosec_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_prisec_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_classpool_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_ct_name( lv_class_name ) TO rt_includes.
    APPEND cl_oo_classname_service=>get_cs_name( lv_class_name ) TO rt_includes.

    lt_methods = cl_oo_classname_service=>get_all_method_includes( lv_class_name ).
    LOOP AT lt_methods ASSIGNING <ls_method>.
      APPEND <ls_method>-incname TO rt_includes.
    ENDLOOP.

  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~get_class_properties.
    CALL FUNCTION 'SEO_CLIF_GET'
      EXPORTING
        cifkey       = is_class_key
        version      = seoc_version_active
      IMPORTING
        class        = rs_class_properties
      EXCEPTIONS
        not_existing = 1
        deleted      = 2
        model_only   = 3
        OTHERS       = 4.
    IF sy-subrc = 1.
      RETURN. " in case only inactive version exists
    ELSEIF sy-subrc <> 0.
      lcx_exception=>raise( 'error from seo_clif_get' ).
    ENDIF.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~read_text_pool.
    DATA:
     lv_cp TYPE program.

    lv_cp = cl_oo_classname_service=>get_classpool_name( iv_class_name ).
    READ TEXTPOOL lv_cp INTO rt_text_pool LANGUAGE iv_language. "#EC CI_READ_REP
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~read_sotr.
    DATA: lv_concept    TYPE sotr_head-concept,
          lt_seocompodf TYPE STANDARD TABLE OF seocompodf WITH DEFAULT KEY,
          ls_header     TYPE sotr_head,
          lt_entries    TYPE sotr_text_tt.

    FIELD-SYMBOLS: <ls_sotr>       LIKE LINE OF rt_sotr,
                   <ls_seocompodf> LIKE LINE OF lt_seocompodf,
                   <ls_entry>      LIKE LINE OF lt_entries.


    SELECT * FROM seocompodf
      INTO TABLE lt_seocompodf
      WHERE clsname = iv_object_name
      AND version = '1'
      AND exposure = '2'
      AND attdecltyp = '2'
      AND type = 'SOTR_CONC'
      ORDER BY PRIMARY KEY.

    LOOP AT lt_seocompodf ASSIGNING <ls_seocompodf>.

      lv_concept = translate( val = <ls_seocompodf>-attvalue from = '''' to = '' ).

      CALL FUNCTION 'SOTR_GET_CONCEPT'
        EXPORTING
          concept        = lv_concept
        IMPORTING
          header         = ls_header
        TABLES
          entries        = lt_entries
        EXCEPTIONS
          no_entry_found = 1
          OTHERS         = 2.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      CLEAR: ls_header-paket,
             ls_header-crea_name,
             ls_header-crea_tstut,
             ls_header-chan_name,
             ls_header-chan_tstut.

      LOOP AT lt_entries ASSIGNING <ls_entry>.
        CLEAR: <ls_entry>-version,
               <ls_entry>-crea_name,
               <ls_entry>-crea_tstut,
               <ls_entry>-chan_name,
               <ls_entry>-chan_tstut.
      ENDLOOP.

      APPEND INITIAL LINE TO rt_sotr ASSIGNING <ls_sotr>.
      <ls_sotr>-header = ls_header.
      <ls_sotr>-entries = lt_entries.

    ENDLOOP.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~delete.
    CALL FUNCTION 'SEO_CLASS_DELETE_COMPLETE'
      EXPORTING
        clskey       = is_deletion_key
      EXCEPTIONS
        not_existing = 1
        is_interface = 2
        db_error     = 3
        no_access    = 4
        other        = 5
        OTHERS       = 6.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'Error from SEO_CLASS_DELETE_COMPLETE' ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.

CLASS lcl_object_oriented_interface DEFINITION
  INHERITING FROM lcl_object_oriented_base.
  PUBLIC SECTION.
    METHODS:
      lif_object_oriented_object_fnc~create REDEFINITION,
      lif_object_oriented_object_fnc~get_includes REDEFINITION,
      lif_object_oriented_object_fnc~get_interface_properties REDEFINITION,
      lif_object_oriented_object_fnc~delete REDEFINITION.
ENDCLASS.

CLASS lcl_object_oriented_interface IMPLEMENTATION.
  METHOD lif_object_oriented_object_fnc~create.
    CALL FUNCTION 'SEO_INTERFACE_CREATE_COMPLETE'
      EXPORTING
        devclass        = iv_package
        overwrite       = iv_overwrite
      CHANGING
        interface       = is_properties
      EXCEPTIONS
        existing        = 1
        is_class        = 2
        db_error        = 3
        component_error = 4
        no_access       = 5
        other           = 6
        OTHERS          = 7.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'Error from SEO_INTERFACE_CREATE_COMPLETE' ).
    ENDIF.
  ENDMETHOD.
  METHOD lif_object_oriented_object_fnc~get_includes.
    DATA lv_interface_name TYPE seoclsname.
    lv_interface_name = iv_object_name.
    APPEND cl_oo_classname_service=>get_interfacepool_name( lv_interface_name ) TO rt_includes.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~get_interface_properties.
    CALL FUNCTION 'SEO_CLIF_GET'
      EXPORTING
        cifkey       = is_interface_key
        version      = seoc_version_active
      IMPORTING
        interface    = rs_interface_properties
      EXCEPTIONS
        not_existing = 1
        deleted      = 2
        model_only   = 3
        OTHERS       = 4.
    IF sy-subrc = 1.
      RETURN. " in case only inactive version exists
    ELSEIF sy-subrc <> 0.
      lcx_exception=>raise( 'error from seo_clif_get' ).
    ENDIF.
  ENDMETHOD.

  METHOD lif_object_oriented_object_fnc~delete.
    CALL FUNCTION 'SEO_INTERFACE_DELETE_COMPLETE'
      EXPORTING
        intkey       = is_deletion_key
      EXCEPTIONS
        not_existing = 1
        is_class     = 2
        db_error     = 3
        no_access    = 4
        other        = 5
        OTHERS       = 6.
    IF sy-subrc <> 0.
      lcx_exception=>raise( 'Error from SEO_INTERFACE_DELETE_COMPLETE' ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lth_oo_factory_injector DEFINITION DEFERRED.

CLASS lcl_object_oriented_factory DEFINITION
  FRIENDS lth_oo_factory_injector.
  PUBLIC SECTION.
    CLASS-METHODS:
      make
        IMPORTING
          iv_object_type                   TYPE tadir-object
        RETURNING
          VALUE(ro_object_oriented_object) TYPE REF TO lif_object_oriented_object_fnc.
  PRIVATE SECTION.
    CLASS-DATA:
        go_object_oriented_object TYPE REF TO lif_object_oriented_object_fnc.
ENDCLASS.
CLASS lcl_object_oriented_factory IMPLEMENTATION.
  METHOD make.
    IF go_object_oriented_object IS BOUND.
      ro_object_oriented_object = go_object_oriented_object.
      RETURN.
    ENDIF.
    IF iv_object_type = 'CLAS'.
      CREATE OBJECT ro_object_oriented_object TYPE lcl_object_oriented_class.
    ELSEIF iv_object_type = 'INTF'.
      CREATE OBJECT ro_object_oriented_object TYPE lcl_object_oriented_interface.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lth_oo_factory_injector DEFINITION FOR TESTING.
  PUBLIC SECTION.
    CLASS-METHODS:
      inject
        IMPORTING
          io_object_oriented_object TYPE REF TO lif_object_oriented_object_fnc.
ENDCLASS.
CLASS lth_oo_factory_injector IMPLEMENTATION.
  METHOD inject.
    lcl_object_oriented_factory=>go_object_oriented_object = io_object_oriented_object.
  ENDMETHOD.
ENDCLASS.
