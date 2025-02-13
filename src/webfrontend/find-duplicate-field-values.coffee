class FindDublicateFieldValues extends CustomMaskSplitter

  isSimpleSplit: ->
    false

  isEnabledForNested: ->
    return true

  isSimpleSplit: ->
    return false

  renderAsField: ->
    return true

  # Original onClick function
  originalOnClick = (evt, button) ->
    return

  # Override onClick of infoButton
  newOnClick = (evt, button) ->
     # generate content for modal
     searchResults = button.opts.searchResults
     # if pool, show pool-path, else show objecttype
     objecttype = searchResults[0]._objecttype
     hasPool = false
     if searchResults[0][objecttype]?._pool?._path
       hasPool = true
       firstRowLabel = $$('fylr-plugin-find-duplicate-field-values.modal.open.pool')
     else
       firstRowLabel = $$('fylr-plugin-find-duplicate-field-values.modal.open.objecttype')
     content = '<table>'
     content += '<tr><th>' + firstRowLabel + '</th><th>ID</th><th>' + $$('fylr-plugin-find-duplicate-field-values.modal.open.shortinfo_standard') + '</th><th>' + $$('fylr-plugin-find-duplicate-field-values.modal.open.link') + '</th></tr>'
     for object in searchResults
       content += '<tr>'
       if hasPool == false
         content += '<td>' + object._objecttype + '</td>'
       else
         fullPath = []
         for pathElem in object[objecttype]._pool._path
           fullPath.push pathElem.pool.name[ez5.loca.getLanguage()]
         content += '<td>' + fullPath.join(' > ') + '</td>'
       content += '<td>' + object._system_object_id + '</td>'
       content += '<td>' + object._standard[1].text[ez5.loca.getLanguage()] + '</td>'
       link = window.location.origin + '/#/detail/' + object._uuid
       content += '<td><a href="' + link + '" target="_blank">/#/detail/' + object._uuid + '</a></td>'
       content += '</tr>'
     content += '</table>'

     modal = new CUI.Modal
                class: "fylr-plugin-find-duplicate-field-values-info-modal"
                pane:
                  content: new CUI.Pane
                              class: "dublicate-info-standard-display"
                  footer_right: =>
                    [
                      new CUI.Button
                        text: "Ok"
                        class: "dublicate-info-standard-display-ok-button"
                        primary: true
                        onClick: =>
                          modal.destroy()
                    ]
     modal.show()

     standardInfoPane = CUI.dom.matchSelector(modal, ".dublicate-info-standard-display")[0]
     standardInfoPane.innerHTML = content

     modal.autoSize()

  _performSearchAndAdjustButton: (value, objecttype, full_name, infoButton) ->
    url = window.easydb_server_url + '/api/v1/search'
    ez5.api.search
      type: "POST"
      json_data:
        limit: 100
        format: 'full'
        generate_rights: false
        objecttypes: [objecttype]
        search: [
           type: 'match',
           mode: 'fulltext',
           fields: [
              full_name
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
      # show button if more than 0 hit(s)
      if data.objects.length > 1
        infoButton.opts.searchResults = data.objects
        infoButton.show()

      # hide button of no hits
      if data.objects.length == 0
        infoButton.hide()

      CUI.Events.trigger
        type: "viewport-resize"

      if infoButton.opts.onClick
        infoButton._onClick = newOnClick.bind(infoButton)
    return



  renderField: (opts) ->
    that = @

    # splitter nur nutzen, wenn die passende gruppe konfiguriert ist
    allowedGroups = @_getAllowedGroupdIDs()
    userGroups = ez5.session.user.getGroups()
    isAllowedUse = false
    for group in userGroups
      if allowedGroups.includes group.id
        isAllowedUse = true

    # or if root-user
    if ez5.session.user.id == 1
      isAllowedUse = true

    # if use not allowed
    if ! isAllowedUse
      return CUI.dom.append(@renderInnerFields(opts))

    # is the splitter in an nested summary?
    isInSummary = false
    if opts?.__is_in_nested_summary
      isInSummary = opts.__is_in_nested_summary

    # get inner fields
    innerFields = @renderInnerFields(opts)

    # no action in other modes than editor
    if opts.mode != 'editor' || isInSummary == true
      return innerFields

    configuredField = @getDataOptions()?.fieldtotestforduplicates

    if configuredField == null
      return innerFields

    fieldsRendererPlain = @__customFieldsRenderer.fields[0]
    fields = fieldsRendererPlain.getFields() or []

    #####################################################################################
    # EDITOR-Mode
    #####################################################################################
    if opts.mode == "editor" && !isInSummary
      if fields
        field = fields[0]
        innerFieldsCollection = @renderInnerFields(opts)

        # get objecttype-name
        objecttype = opts.top_level_data._objecttype

        selectedElement = innerFieldsCollection.item(0)

        fieldnameblock = selectedElement.querySelector('.ez5-field-block-header')

        copiedFieldnameBlock = fieldnameblock.cloneNode(true)

        # create layout for splitter
        # add button, click on button opens the searchresultsdisplay for records, which also have the same value in that field
        infoButton = new CUI.Button
                        text: $$('fylr-plugin-find-duplicate-field-values.info.link')
                        class: 'fylr-plugin-find-duplicate-field-values-info-found-link'
                        icon_left: new CUI.Icon(class: "fa-info-circle")
                        size: "big"
                        appearance: "link"
                        onClick: originalOnClick

        verticalLayout = new CUI.VerticalLayout
          class: "fylr-plugin-find-duplicate-field-values editormode"
          maximize: true
          center:
            content:
                      infoButton
          bottom:
            content:
                      new CUI.HorizontalLayout
                        class:  "fylr-plugin-find-duplicate-field-values-input-layout"
                        left:
                          content: ''
                        center:
                          content: innerFieldsCollection

        # infoButton is hidden by default
        infoButton.hide()

        # if field has a value, search for dublicate values
        if opts.data[field.ColumnSchema.name]
          # do search
          fieldValue = opts.data[field.ColumnSchema.name]
          @._performSearchAndAdjustButton(fieldValue, objecttype, field.__dbg_full_name, infoButton)

        # listen for changes in field
        CUI.Events.listen
          type: ["data-changed"]
          node: selectedElement
          call: (ev, info) =>
            # if value is not empty
            hasValue = false
            if opts.data[field.ColumnSchema.name]
              fieldValue = opts.data[field.ColumnSchema.name]
              @._performSearchAndAdjustButton(fieldValue, objecttype, field.__dbg_full_name, infoButton)

        div = CUI.dom.element("div", class: "fylr-plugin-find-duplicate-field-values" )
        return CUI.dom.append(div, verticalLayout)
    return


  # get groups, of which users are allowed to use this plugin
  _getAllowedGroupdIDs: ->
    baseConfig = ez5.session.getBaseConfig("plugin", "find-duplicate-field-values")
    config = baseConfig['FindDuplicateFieldvalues']['find_duplicate_field_values'] || baseConfig['FindDuplicateFieldvalues']
    allowedGroups = []
    if config
      for group in config
        allowedGroups.push group.group_id
    return allowedGroups


  ##########################################################################################
  # make Option out of linked-table
  ##########################################################################################

  __getOptionsFromLinkedTable: (linkedField, linkTableName)->
    newOptions = []
    for field in linkedField.mask.fields
      if field.kind == 'field'
        parts = field._full_name.split('.')
        objecttype = parts[0]
        nested = '_nested:' + parts[1]
        fieldName = parts[2]
        fieldSearchPath = objecttype + '.' + nested + '.' + fieldName
        newOption =
          value: fieldSearchPath
          test: fieldSearchPath
        newOptions.push newOption
    return newOptions

  ##########################################################################################
  # get Options from MaskSettings
  ##########################################################################################

  getOptions: ->
    that = @
    # write the available fields from editor to select in maskconfig
    fieldOptions = []

    # leere Option
    emptyOption =
        value : null
        text : $$('fylr-plugin-find-duplicate-field-values.options.empty')

    fieldOptions.push emptyOption

    fieldsFound = false

    # presents only level 0 and level 1 for the selection
    if @opts?.maskEditor
      fields = @opts.maskEditor.opts.schema.fields
      for field in fields
        if field.kind == 'field'
          newOption =
            value : field._full_name
            text : field._full_name
          fieldOptions.push newOption
          fieldsFound = true
        if field.kind == 'linked-table'
          linkTableName = field.other_table_name_hint
          test = @__getOptionsFromLinkedTable(field, linkTableName)
          if test
            fieldsFound = true
          fieldOptions = fieldOptions.concat test

    # show hint, if record was not saved yet
    if ! fieldsFound
      fieldOptions = []
      emptyOption =
          value : null
          text : $$('fylr-plugin-find-duplicate-field-values.options.empty_save')

      fieldOptions.push emptyOption

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
