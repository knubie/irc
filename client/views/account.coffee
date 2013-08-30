# Set up flat checkboxes
Template.account.rendered = ->
  $('[data-toggle="checkbox"]').each ->
    $checkbox = $(this)
    $checkbox.checkbox()

# Preserver flat checkboxes
Template.account.preserve [
  '.checkbox'
  '#playSounds'
  '#sendNotifications'
  '.icons'
]
