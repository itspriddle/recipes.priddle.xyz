---
permalink: /
layout: default
home: true
---

🎂 and 🍝 and lots of <span class="color-mode-toggle">🧀</span>

<ul>
{% assign recipes = site.static_files | where: "recipe", true %}
{% for recipe in recipes %}
  <li>
    <a href="{{ recipe.path | replace: ".md", ".html" | uri_escape }}">{{ recipe.recipe_title | smartify }}</a>
  </li>
{% endfor %}
</ul>
