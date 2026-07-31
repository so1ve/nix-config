{
  hasFeatureEnabled,
}:

{
  href,
  icon,
  id,
  title,
}:

if hasFeatureEnabled "software/dolphin" then
  {
    ray.dolphin.places.${id} = {
      inherit href icon title;
    };
  }
else
  { }
