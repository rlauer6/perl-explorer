
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

  $(comments).each(function() {
    $(this).addClass('pe-critic');
  });
  
});
