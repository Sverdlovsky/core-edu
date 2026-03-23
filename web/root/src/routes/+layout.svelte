<script lang="ts">
    import "../app.css";
    import Navbar from "$lib/Navbar.svelte";

    let domainCut = window.location.hostname.split('.').slice(-2)
    let domain = domainCut.join('.');
    let title = domainCut[0].charAt(0).toUpperCase() + domainCut[0].slice(1);
</script>

<svelte:head>
    <link rel="icon" href="/svg/favicon.svg"/>
    <title>{title}</title>
</svelte:head>

<slot />

<Navbar />
