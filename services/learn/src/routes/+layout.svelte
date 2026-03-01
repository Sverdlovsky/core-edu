<script lang="ts">
    import "../app.css";
    import { domain, theme } from "$lib/stores";

    domain.set("example.com");
</script>

<svelte:head>
    <link rel="icon" href="/static/logo.png" />
    <title>OpenMediaHub</title>
</svelte:head>

<slot />
