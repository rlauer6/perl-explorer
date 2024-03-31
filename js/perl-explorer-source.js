// ########################################################################
// (c) Copyright 2024, TBC Development Group, LLC
// All rights reserved.
// ########################################################################

// ########################################################################
$(document).ready(function () {
  // ########################################################################

  var comments = $('span.comment').filter(function() {
    return  $(this).text().indexOf('no critic') > -1;
  });

  // ###################################################################
  // light up no critic - possible TODOs?
  // ###################################################################
  $(comments).each(function() {
    $(this).addClass('pe-critic');
  });

  // ###################################################################
  // TODO
  // ###################################################################
  $('.linenum').on('click', function() {
    $('#pe-todo-text').val('');

    $('#todo-linenum').val($(this).text());
    open_modal('pe-todo-container');
  });

  $('#pe-todo-cancel').on('click', function() {
    close_modal('pe-todo-container');
  });

  $('#pe-todo-save').on('click', function() {
    close_modal('pe-todo-container');

    save_todo();
  });

  $('#pe-source-info-icon').on('click', function() {
    open_modal('pe-source-info');
  });

  $('#pe-source-info button').on('click', function() {
    close_modal('pe-source-info');
  });

  $('#pe-search-cancel').on('click', function() {
    close_modal('pe-search-container');
  });

  $('#pe-search-search').on('click', function() {
    search_text();
  });

  $('#pe-search-icon').on('click', function() {
    open_modal('pe-search-container');
  });

  $('#pe-search-results-cancel').on('click', function() {
    $('#pe-search-results').css('display', 'none');
    // close_modal('pe-search-results');
  });

  // ###################################################################
  // dependencies dropdown
  // ###################################################################

  $('#pe-dependencies').on('change', function () {
    var is_local = $('#pe-dependencies').val();

    module = $('#pe-dependencies option:selected').text();

    if ( is_local == "1" ) {
      var repo = $('#repo').val();
      window.open('/explorer/' + repo + '/source/' + module, '_blank');
    }
    else {
      window.open('/explorer/pod/' + module, '_blank');
    }

  });

  // ###################################################################
  // reverse dependencies dropdown
  // ###################################################################

  $('#pe-reverse-dependencies').on('change', function () {

    module = $('#pe-reverse-dependencies option:selected').text();

    if ( module != '-- Select --' ) {
      var repo = $('#repo').val();
      window.open('/explorer/' + repo + '/source/' + module, '_blank');
    }

  });

  $('#pe-reverse-dependencies').val('').prop('selected', true);


  if (linenum && linenum != 1) {
    highlight_line(linenum);

    show_page_up();
  }
  else {
    location.href = '#pe-1'

    show_page_down();
  }

  lineum = 1;

  // ###################################################################
  // subs dropdown
  // ###################################################################
  $('#pe-subs').on('change', function() {

    if ( !this.value ) {
      location.href = '#pe-1';

      remove_highlights();

      return;
    }

    var linenum = parseInt(this.value);

    highlight_line(linenum);
  });
});


// #####################################################################
function remove_highlights() {
  // #####################################################################
  $('.pe-linenum-selected').removeClass('pe-linenum-selected');
}

// #####################################################################
function highlight_line(linenum) {
  // #####################################################################
  var anchor = '#pe-' + linenum;

  var elem = $('a[name="pe-' + linenum + '"]');

  remove_highlights();

  $(elem).addClass('pe-linenum-selected');

  elem = $(elem).next();

  while (elem && ! $(elem).is('a') ) {

    $(elem).addClass('pe-linenum-selected');
    elem = $(elem).next();
  }

  show_page_up();

  location.href = anchor;
}


// #####################################################################
function show_page_up() {
  // #####################################################################
  $('.pe-pager').removeClass('fa-caret-down');
  $('.pe-pager').addClass('fa-caret-up');

  $('.pe-pager').off('click');

  $('.pe-pager').on('click', function() {

    location.href = '#pe-1';

    show_page_down();
  });
}

// #####################################################################
function show_page_down() {
  // #####################################################################
  remove_highlights();

  $('.pe-pager').removeClass('fa-caret-up');
  $('.pe-pager').addClass('fa-caret-down');

  $('.pe-pager').off('click');

  $('.pe-pager').on('click', function() {

    location.href = '#pe-' + $('tt a').length;

    show_page_up();
  });
}

// #####################################################################
function save_todo() {
  // #####################################################################
  var module = $('title').text();

  var data = {
    todos : [ $('#todo-linenum').val(), $('#pe-todo-text').val() ],
    module: $('title').text()
  };

  $('body').addClass('loading');

  $.ajax({
    url: '/explorer/source/todos',
    dataType: 'json',
    data: JSON.stringify(data),
    method: 'POST',
    contentType: 'application/json'
  }).done(function (data) {
    $('body').removeClass('loading');

    display_success_message('Successfully saved your TODO!', true, function () {
      $('body').addClass('loading');
      location.reload(0);
    });

    return true;
  }).fail(function($xhr, status, error) {

    console.log($xhr);
    console.log(status);
    console.log(error);

    data = $xhr.responseJSON;

    $('body').removeClass('loading');

    display_error_message(data.html_error, true, null);

    return false;
  });


  return;
}

// #####################################################################
function search_text() {
  // #####################################################################
  var text = $('#pe-search-text').val();

  var is_repo_search = $('#pe-repo-search').is(":checked");

  var repo_search = is_repo_search ? 1 : 0;

  var regexp = $('#pe-regexp').is(":checked");

  regexp = regexp ? 1 : 0;

  var module = $('title').text();

  close_modal('pe-search-container');

  $('body').addClass('loading');

  $.ajax({
    url: '/explorer/source/search',
    data: {
      'repo-search': repo_search,
      'search-term': text,
      'regexp': regexp,
      'module': module
    }
  }).done(function (data) {

    $('body').removeClass('loading');

    $('#pe-search-results-table').DataTable().destroy();

    $('#pe-search-results-table tbody').replaceWith('<tbody></tbody>');

    $('.pe-search-linenum, .pe-search-module').off('click');

    if ( repo_search ) {
      if ( !data.length ) {
        display_error_message('nothing found');
      }

      data.forEach(function(result) {
        var module = result[1];
        var module_result = result[0];

        module_result.forEach(function(result) {
          add_row(module, result);
        });
      });

      set_linenum_handler(0);
    }
    else {
      data.forEach(function(result) {
        add_row(module, result);
      });

      set_linenum_handler(1);
    }

    // set handler to move to internal href if this module
    $('.pe-search-module').filter(function() {
      return module == $(this).text(); }).each(function() {
        $(this).off('click');
        $(this).on('click', function() {
          move_to_linenum(this);
        });
      });

    $('#pe-search-results-table').DataTable({
      bAutoWidth: false,
      columns: [ null, null, { width: "100%" } ]
    });

    $('#pe-search-results').css('display', 'inline-block');

    // open_modal('pe-search-results');
    $('#pe-search-results').mousedown(handle_mousedown);

    return true;
  }).fail(function($xhr, status, error) {

    console.log($xhr);
    console.log(status);
    console.log(error);

    data = $xhr.responseJSON;

    $('body').removeClass('loading');

    display_error_message(data.html_error, true, null);

    return false;
  });

}

// #####################################################################
function move_to_linenum(elem) {
  // #####################################################################

  var linenum = $(elem).parent().find('.pe-search-linenum').text();

  remove_highlights();

  highlight_line(linenum);

  linenum = '#pe-' + linenum;

  location.href = linenum;
}

// #####################################################################
function set_linenum_handler(is_local) {
  // #####################################################################
  if ( is_local ) {
    $('.pe-search-linenum, .pe-search-module').on('click', function() {
      move_to_line( elem, linenum);
    });
  }
  else {
    $('.pe-search-module').on('click', function() {
      var linenum = $(this).next().text();
      var url = '/explorer/source/' + $(this).text() + '?linenum=' + linenum;

      window.open(url, '_blank');
    });
  }
}

// #####################################################################
function add_row(module, result) {
  // #####################################################################
  var linenum = result[0];
  var line = result[1];

  $('#pe-search-results-table tbody').append('<tr><td class="pe-search-module">' + module + '</td><td class="pe-search-linenum">'+ linenum + '</td><td>' + line + '</td></tr>');
}

// #####################################################################
function handle_mousedown(e){
  // #####################################################################

  $(this).css('cursor', 'move');

  window.my_dragging = {};

  my_dragging.pageX0 = e.pageX;
  my_dragging.pageY0 = e.pageY;
  my_dragging.elem = this;
  my_dragging.offset0 = $(this).offset();

  function handle_dragging(e){
    var left = my_dragging.offset0.left + (e.pageX - my_dragging.pageX0);
    var top = my_dragging.offset0.top + (e.pageY - my_dragging.pageY0);
    $(my_dragging.elem)
      .offset({top: top, left: left});
  }

  function handle_mouseup(e){
    $('#pe-search-results').css('cursor', 'default');

    $('body')
      .off('mousemove', handle_dragging)
      .off('mouseup', handle_mouseup);
  }

  $('body')
    .on('mouseup', handle_mouseup)
    .on('mousemove', handle_dragging);
}
