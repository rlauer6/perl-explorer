// ########################################################################
$(document).ready(function () {
// ########################################################################
  $('#pe-markdown-select').on('change', function() {
    window.open("/explorer/markdown/" + $(this).val(), '_blank');
  });

  var md_id = window.location.pathname.split("/").pop()

  if ( md_id ) {
    $('#pe-markdown-select').val(md_id);
  }
});


