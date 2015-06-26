(($) ->
  bind_data = (china_city, parent, child) ->
    china_city.on 'change', parent, ->
      child_select = china_city.find(child)
      child_select.find('option').slice(1).remove()
      child_select.change()
      value = $(this).find(':checked').data('value')
      if value?
        child_select.trigger('china_city:load_data_start');
        $.get "/china_city/#{value}", { postal_code: true } , (data) ->
          $('<option>', {value: option[0], text: option[0]}).data('value', option[1]).data('postal_code', option[2]).appendTo(child_select) for option in data
          # init value after data completed.
          child_select.trigger('china_city:load_data_completed');

  $.fn.china_city = (options) ->
    options = $.extend
      state: '.state'
      city: '.city'
      district: '.district'
      street: '.street'
    , options

    this.each (index, china_city) ->
      bind_data $(china_city), options.state, options.city
      bind_data $(china_city), options.city, options.district
      bind_data $(china_city), options.district, options.street

  $(document).on 'ready page:load', ->
    $('.china-city').china_city()
)(jQuery)
