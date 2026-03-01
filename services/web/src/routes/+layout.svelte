<script lang="ts">
    import "../app.css";
    import Navbar from "$lib/Navbar.svelte";
    import { domain, theme } from "$lib/stores";

    domain.set("example.com");
</script>

<svelte:head>
    <link
        rel="icon"
        href={`https://media.${$domain}/icons/${$theme}/favicon.svg`}
    />
    <title>OpenMediaHub</title>
</svelte:head>

<slot />

<Navbar />
