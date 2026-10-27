# Hostile document

Every item below must render inert.

<script>document.body.innerHTML = "PWNED by script"</script>

<img src="x" onerror="document.body.innerHTML='PWNED by onerror'">

<iframe src="https://example.com"></iframe>

[javascript link](javascript:document.body.innerHTML='PWNED')

[file link](file:///etc/passwd)

![escape the root](../../../../../../etc/hosts)

<a href="#" onclick="document.body.innerHTML='PWNED'">raw anchor</a>
