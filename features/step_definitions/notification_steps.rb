Given /^a Chef cookbook with a recipe in which a template notifies a service$/ do
  recipe_with_template_notifying_service
end

Given /^the recipe has a spec example that assert on the notification$/ do
 spec_expects_template_notifies_service 
end

Then /the notify assertion will be succesfully evaluated/ do
end

