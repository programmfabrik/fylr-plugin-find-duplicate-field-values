class FindDublicateFieldValues extends CustomMaskSplitter

  isSimpleSplit: ->
    false

  isEnabledForNested: ->
    return true

  _getAllowedFieldTypes: ->
    allowedTypes = [
      'text_oneline'
    ]
    return allowedTypes

  isSimpleSplit: ->
    return false

  renderAsField: ->
    return true

  renderField: (opts) ->
    that = @
    console.warn "opts", opts

    # get objecttype-name
    objecttype = opts.top_level_data._objecttype

    # Gruppeneditor? --> den Splitter nicht nutzen
    if opts.bulk && opts.mode == "editor-bulk"
      return CUI.dom.append(@renderInnerFields(opts))

    # get inner fields
    innerFields = @renderInnerFields(opts)

    defaultValueFromPool = ''
    for key, entry of customDataFromPool
      if key == @getDataOptions().defaultInfoLinkFromPool
        defaultValueFromPool = entry
        if typeof defaultValueFromPool == 'object'
          defaultValueFromPool = defaultValueFromPool?.conceptName

    fieldsRendererPlain = @__customFieldsRenderer.fields[0]
    fields = fieldsRendererPlain.getFields() or []

    #####################################################################################
    # EDITOR-Mode
    #####################################################################################

    if opts.mode == "editor" || opts.mode == "editor-bulk"
      if fields
        field = fields[0]
        console.log "fields", fields

        innerFieldsCollection = @renderInnerFields(opts)

        console.log "innerFieldsCollection", innerFieldsCollection

        selectedElement = innerFieldsCollection.item(0)

        console.log "selectedElement", selectedElement

        fieldnameblock = selectedElement.querySelector('.ez5-field-block-header')

        copiedFieldnameBlock = fieldnameblock.cloneNode(true)

        selectedElement.querySelector('.ez5-field-block-header').style.display = 'none'

        # in input einen placeholder setzen
        testForInput = selectedElement.querySelector('.cui-input input')
        if testForInput
          testForInput.placeholder = $$('fylr-plugin-default-values-from-pool-default-value.splitter.placeholder')

        # wenn Feld einen Wert hat, dann Button anzeigen, ansonsten verstecken
        # wenn Feld einen Wert hat, dann Standardwert nicht anzeigen
        buttonClassHidden = ''
        labelClassHidden = 'show'
        if opts.data[field.ColumnSchema.name]
          buttonClassHidden = 'show'
          labelClassHidden = ''
          if opts.data[field.ColumnSchema.name]?.conceptURI == ''
            labelClassHidden = 'show'
            buttonClassHidden = ''

        # x-button for splitter-layout
        xButton = new CUI.Button
          class: 'fylr-plugin-default-values-from-pool-x-button ' + buttonClassHidden
          icon_left: new CUI.Icon(class: "fa-times")
          tooltip:
            text: $$('fylr-plugin-default-values-from-pool-default-value-remove-custom-value')
          onClick: (evt,button) =>
            console.log("clicked button")
            # clear value of field
            console.log "selectedElement", selectedElement
            dataField = CUI.dom.matchSelector(selectedElement, ".cui-data-field")[0]
            console.log "dataField", dataField
            domData = CUI.dom.data(dataField, "element")
            console.log "domData", domData
            # if dante
            type = domData.__cls
            if type == 'Form'
              console.log "$$$$$$$$$ type=FORM"
              domData.unsetData()
              domData.opts.data = {}
              domData._data = {}
              opts.data[field.ColumnSchema.name] = {}


              #domData.setChanges()
              #domData.initOpts()

              #domData.setData({})
              #domData.reload()
              #domData.reset()
              #domData.init()
              CUI.Events.trigger
                type: 'custom-deleteDataFromPlugin'
                node: selectedElement
                bubble: false
              CUI.Events.trigger
                type: 'editor-changed'
                node: selectedElement
                bubble: true

            # if text_oneline
            if type == 'Input'
              console.log "type=Input"
              domData.setValue('')
              domData.displayValue()

            CUI.Events.trigger
              type: 'data-changed'
              node: dataField
              bubble: true
            CUI.Events.trigger
              type: 'editor-changed'
              node: dataField
              bubble: true

        # Element, welches den Standardwert aus dem Pool anzeigt
        defaultLabelElement = new CUI.Label
                                     text: defaultValueFromPool + ' (' + $$('fylr-plugin-default-values-from-pool-default-value.splitter.hint') + ')'
                                     class: 'fylr-plugin-default-values-from-pool-default-value ' + labelClassHidden

        # creatre layout for splitter
        verticalLayout = new CUI.VerticalLayout
          class: "fylr-plugin-default-values-from-pool editormode"
          maximize: true
          top:
            class: 'fylr-plugin-default-values-from-pool-header'
            content: copiedFieldnameBlock
          center:
            content: defaultLabelElement
          bottom:
            content:
                      new CUI.HorizontalLayout
                        class:  "fylr-plugin-default-values-from-pool-input-layout"
                        left:
                          content: ''
                        center:
                          content: innerFieldsCollection
                        right:
                          content: xButton

        # listen for changes in field
        CUI.Events.listen
          type: ["data-changed"]
          node: selectedElement
          call: (ev, info) =>
            console.log "value changed!!!"
            # if value is not empty, hide default value and show button
            hasValue = false
            if opts.data[field.ColumnSchema.name]
              hasValue = true
              if opts.data[field.ColumnSchema.name]?.conceptURI == '' || opts.data[field.ColumnSchema.name]?.conceptURI == null
                opts.data[field.ColumnSchema.name] = {}
                hasValue = false
            console.log "hasValue", hasValue
            console.log "opts.data[field.ColumnSchema.name]", opts.data[field.ColumnSchema.name]
            console.log "xButton", xButton

            console.log "defaultLabelElement", defaultLabelElement

            if hasValue
              # show button
              CUI.dom.addClass(xButton, 'show')
              # show default value
              CUI.dom.removeClass(defaultLabelElement, 'show')
            else
              # hide button
              CUI.dom.removeClass(xButton, 'show')
              # hide default value
              CUI.dom.addClass(defaultLabelElement, 'show')

            CUI.Events.trigger
              type: 'editor-changed'
              node: selectedElement
              bubble: true

        CUI.Events.registerEvent
          type: "custom-deleteDataFromPlugin"
          bubble: false

        return CUI.dom.append(verticalLayout)
    return

  _getAllowedGroupdIDs: ->
    # get groups, of which users are allowed to use this plugin
    baseConfig = ez5.session.getBaseConfig("plugin", "find-duplicate-field-values")
    config = baseConfig['FindDuplicateFieldvalues']['find_duplicate_field_values'] || baseConfig['FindDuplicateFieldvalues']
    allowedGroups = []
    if config
      for group in config
        allowedGroups.push group.group_id
      console.log "allowedGroups", allowedGroups
    return allowedGroups


  getOptions: ->
    that = @
    # write the available fields from editor to select in maskconfig
    fieldOptions = []
    if @opts?.maskEditor
      fields = @opts.maskEditor.opts.schema.fields
      for field in fields
        if field.kind == 'field'
          if field._column.type == 'text_oneline'
            newOption =
              value : field._full_name
              text : field._column._name_localized + ' [' + field.column_name_hint + '] ("' + field._full_name + '")'
            fieldOptions.push newOption

    maskOptions = [
      form:
        label: $$('find.duplicate.field.values.fieldtotestforduplicates')
      type: CUI.Select
      name: "fieldtotestforduplicates"
      options: fieldOptions
    ]
    maskOptions

  trashable: ->
    true

CUI.ready =>
  MaskSplitter.plugins.registerPlugin(FindDublicateFieldValues)
