---
layout: default
---

🎂 and 🍝 and lots of 🧀

<ul>
{% assign recipes = site.static_files | where: "recipe", true %}
{% for recipe in recipes %}
  <li>
    <a href="{{ recipe.path | replace: ".md", ".html" | uri_escape }}">{{ recipe.basename }}</a>
  </li>
{% endfor %}
</ul>
