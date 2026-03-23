<script lang="ts">
    let domainCut = window.location.hostname.split('.').slice(-2)
    let domain = domainCut.join('.');
    let title = domainCut[0].charAt(0).toUpperCase() + domainCut[0].slice(1);

    let search_active = false;
    let search_text = "";
</script>

<div class="navbar">
    <a href="/" style="width: 192px; grid-area: home;">
        <img src="/svg/favicon.svg" alt="favicon" style="width: 48px; height: 48px;"/>
        <h2>{title}</h2>
    </a>
    <div class="search" style="grid-area: search;" class:active={search_active}>
        <button on:click={() => (search_active = !search_active)}>
            <img src="/svg/search.svg" alt="search"/>
        </button>
        <input
            type="text"
            id="search_input"
            placeholder="Search..."
            bind:value={search_text}
        />
        <button id="search_filter">
            <img src="/svg/filter.svg" alt="filter"/>
        </button>
    </div>
    <a href="/favorites" style="grid-area: favorites;">
        <img src="/svg/favorites.svg" alt="favorites"/>
    </a>
    <a href="/settings" style="grid-area: settings;">
        <img src="/svg/settings.svg" alt="settings"/>
    </a>
    <a href={`https://auth.${$domain}/with/yandex`} style="grid-area: profile;">
        <img src="/svg/profile.svg" alt="profile"/>
    </a>
</div>

<style>
    a {
        width: 100%;
        height: 100%;
        display: flex;
        flex-direction: row;
        align-items: center;
        justify-content: center;
        color: inherit;
        gap: 16px;
        transition:
            filter 0.25s ease,
            box-shadow 0.25s ease;
    }

    a:hover {
        filter: drop-shadow(0 0 8px #888888);
    }

    img {
        grid-area: icon;
        width: 28px;
        height: 28px;
        justify-self: center;
    }

    h2 {
        line-height: 0px;
        pointer-events: none;
    }

    p {
        line-height: 0px;
        pointer-events: none;
    }

    button {
        width: 64px;
        height: 100%;
        display: flex;
        justify-content: center;
        align-items: center;
        outline: none;
        border: none;
        background: none;
        cursor: pointer;
    }

    input {
        outline: none;
        border: none;
        background: none;
        font-size: 16px;
        color: white;
    }

    .navbar {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 64px;
        display: grid;
        grid-template-columns: min-content auto 64px 64px 64px;
        grid-template-areas: "home search favorites settings profile";
        justify-items: center;
        align-items: center;
        /*box-shadow: 0px 0px 10px 0px rgba(0, 0, 0, 0.5);*/
    }

    .search {
        width: 64px;
        height: 100%;
        display: flex;
        flex-direction: row;
        justify-self: end;
        justify-content: center;
        align-items: center;
        transition: width 0.25s ease;
    }

    .search.active {
        width: 100%;
    }

    .search.active #search_input,
    .search.active #search_filter {
        display: flex;
        opacity: 1;
        margin: 0px;
    }

    #search_input {
        display: none;
        opacity: 0;
        margin-left: -32px;
        transition:
            margin 0.25s ease,
            opacity 0.25s ease;
    }

    #search_filter {
        display: none;
        opacity: 0;
        margin-left: -192px;
        transition:
            margin 0.25s ease,
            opacity 0.25s ease;
    }
</style>
