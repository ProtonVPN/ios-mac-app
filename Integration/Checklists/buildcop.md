{% for commit in commits %}
{% if commit|attrs:config["failed_pipeline_trailer"] %}
* Record notes for the following failed pipeline:

```txt
{{ commit }}
```
{% endif %}
{% endfor %}
