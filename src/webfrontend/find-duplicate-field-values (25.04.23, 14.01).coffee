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

  _performSearchAndAdjustButton: (value, objecttype, fieldnameForSearch, infoButton) ->
    console.log "f:_performSearch"
    url = window.easydb_server_url + '/api/v1/search'
    ez5.api.search
      type: "POST"
      json_data:
        limit: 100
        format: 'long'
        generate_rights: false
        objecttypes: [objecttype]
        search: [
           type: 'match',
           mode: 'fulltext',
           fields: [
              objecttype + '.' + fieldnameForSearch
           ],
           string: value,
           phrase: false,
           bool: 'must'
        ]
        sort: [
          field: '_system_object_id'
          order: 'DESC'
        ]
    .done (data) =>
      console.log "f:_adjustInfoButton"
      console.log "@", @
      console.log "data.objects", data.objects

      # Buttonsclass: fylr-plugin-find-duplicate-field-values-info-found-link

      # show button if more than 0 hit(s)
      if data.objects.length > 0
        console.log "an"
        infoButton.show()

      # hide button of no hits
      if data.objects.length == 0
        console.log "aus"
        infoButton.hide()

      console.log "infoButton", infoButton
      # selectedElement.querySelector('.ez5-field-block-header')
      #button = CUI.dom.matchSelector(infoButton, ".fylr-plugin-find-duplicate-field-values-info-found-link")[0]
      #console.log "button", button
      #                       document

      ###
       onClick: (evt,button) =>
         console.log "clicked more info button"
         modal = new CUI.Modal
                    class: "fylr-plugin-find-duplicate-field-values-info-modal"
                    pane:
                      content: 'asdasfd as dsa faf asf a asf asd asdf sad'
                      footer_right: =>
                        [
                          new CUI.Button
                            text: "Ok"
                            class: "cui-dialog"
                            primary: true
                            onClick: =>
                              modal.destroy()
                        ]
         console.log "modal", modal
         modal.show()
      ###
    return



  renderField: (opts) ->
    that = @
    console.warn "opts", opts

    # Gruppeneditor? --> den Splitter nicht nutzen
    if opts.bulk && opts.mode == "editor-bulk"
      return CUI.dom.append(@renderInnerFields(opts))

    # get inner fields
    innerFields = @renderInnerFields(opts)

    # no action in detail-mode
    if opts.mode == "detail"
      return innerFields

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

        # get objecttype-name
        objecttype = opts.top_level_data._objecttype
        console.log "objecttype", objecttype

        console.log "innerFieldsCollection", innerFieldsCollection

        selectedElement = innerFieldsCollection.item(0)

        console.log "selectedElement", selectedElement

        fieldnameblock = selectedElement.querySelector('.ez5-field-block-header')

        copiedFieldnameBlock = fieldnameblock.cloneNode(true)

        # create layout for splitter
        verticalLayout = new CUI.VerticalLayout
          class: "fylr-plugin-default-values-from-pool editormode"
          maximize: true
          #top:
          #  class: 'fylr-plugin-default-values-from-pool-header'
          #  content: copiedFieldnameBlock
          center:
            content:
                      # Icon hinzufügen. Bei klick auf Icon vom Label öffnet sich ein
                      # modal, welches die Infos über die Dubletten beinhalten
                      infoButton = new CUI.Button
                                     text: $$('fylr-plugin-find-duplicate-field-values.info.link')
                                     class: 'fylr-plugin-find-duplicate-field-values-info-found-link'
                                     icon_left: new CUI.Icon(class: "fa-info-circle")
                                     size: "big"
                                     appearance: "link"
          bottom:
            content:
                      new CUI.HorizontalLayout
                        class:  "fylr-plugin-default-values-from-pool-input-layout"
                        left:
                          content: ''
                        center:
                          content: innerFieldsCollection

        # wenn Feld einen Wert hat, dann Suche ausführen
        if opts.data[field.ColumnSchema.name]
          console.log "Feld hat einen Wert!!"
          # do search
          console.log "field.ColumnSchema.name", field.ColumnSchema.name

          fieldValue = opts.data[field.ColumnSchema.name]
          console.log "fieldValue", fieldValue
          @._performSearchAndAdjustButton(fieldValue, objecttype, field.ColumnSchema.name, infoButton)

        # listen for changes in field
        CUI.Events.listen
          type: ["data-changed"]
          node: selectedElement
          call: (ev, info) =>
            console.log "value changed!!!"
            # if value is not empty
            hasValue = false
            if opts.data[field.ColumnSchema.name]
              fieldValue = opts.data[field.ColumnSchema.name]
              @._performSearchAndAdjustButton(fieldValue, objecttype, field.ColumnSchema.name, infoButton)

            # # TODO:
            # es braucht dann noch eine Funktion zum Verarbeiten der Infos
            # Ein- bzw. ausblenden der Info

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
