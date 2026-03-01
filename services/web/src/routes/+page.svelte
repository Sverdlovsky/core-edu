<script lang="ts">
    import { domain } from "$lib/stores";
    import { tick } from "svelte";

    type Episode = {
        num: number;
        nru: string;
        unit: number;
    };

    type Franchise = {
        id: string;
        title: string;
        ru: string;
        dsc: string;
        score: number;
        next: Episode;
        fins: number;
    };

    type Pack = {
        id: string;
        title: string;
        franchises: Franchise[];
    };

    const columnOffsets = [32, 96, 128, 64, 160];
    let container: HTMLElement | null = null;
    let isLoading = false;
    let columns: Franchise[][] = $state([]);
    let nextCol = 0;
    let offset = 0;

    function onScroll() {
        if (isLoading) return;

        const scrollTop = document.documentElement.scrollTop;
        const clientHeight = document.documentElement.clientHeight;
        const scrollHeight = document.documentElement.scrollHeight;

        if (scrollTop < 300) {
            if (isLoading) return;
            isLoading = true;

            const url = new URL(
                `https://api.${$domain}/units?offset=${offset}&limit=10`,
            );

            fetch(url)
                .then((res) => {
                    if (!res.ok) {
                        console.error("Request error");
                        return;
                    }
                    return res.json();
                })
                .then((data) => {
                    for (const item of data) {
                        columns[nextCol].unshift(item);
                        nextCol = (nextCol + 1) % columns.length;
                        offset++;
                    }

                    return tick();
                })
                .then(() => {
                    const newHeight = document.documentElement.scrollHeight;
                    const heightDiff = newHeight - scrollHeight;
                    const newTop = document.documentElement.scrollTop;
                    window.scrollTo(0, newTop + heightDiff);

                    isLoading = false;
                })
                .catch((err) => {
                    console.error("Network error", err);
                });
        }
        if (scrollHeight - (scrollTop + clientHeight) < 300) {
            if (isLoading) return;
            isLoading = true;

            const url = new URL(
                `https://api.${$domain}/units?offset=${offset}&limit=10`,
            );

            fetch(url)
                .then((res) => {
                    if (!res.ok) {
                        console.error("Request error");
                        return;
                    }
                    return res.json();
                })
                .then((data) => {
                    for (const item of data) {
                        columns[nextCol].push(item);
                        nextCol = (nextCol + 1) % columns.length;
                        offset++;
                    }

                    return tick();
                })
                .then(() => {
                    isLoading = false;
                })
                .catch((err) => {
                    console.error("Network error", err);
                });
        }
    }

    $effect(() => {
        columns = Array.from({ length: 5 }, () => []);

        const url = new URL(`https://api.${$domain}/units?offset=0&limit=25`);

        fetch(url)
            .then((res) => {
                if (!res.ok) {
                    console.error("Request error");
                    return;
                }
                return res.json();
            })
            .then((data) => {
                for (const item of data) {
                    columns[nextCol].push(item);
                    nextCol = (nextCol + 1) % columns.length;
                    offset++;
                }

                return tick();
            })
            .then(() => {
                window.scrollTo(0, 512);
                if (container) window.addEventListener("scroll", onScroll);
            })
            .catch((err) => {
                console.error("Network error", err);
            });
    });
</script>

<main bind:this={container}>
    <div class="columns">
        {#each columns as column, i}
            <div class="column">
                <div
                    class="placeholder"
                    style="height: {columnOffsets[i]}px"
                ></div>
                {#each column as { id, title, ru, dsc, score, next, fins }}
                    {#if next}
                        {@const { num, nru, unit } = next}
                        <div
                            role="button"
                            tabindex="0"
                            onclick={() =>
                                (window.location.href = `mpv://https%3A//media.${$domain}/units/${id}/mpv.m3u`)}
                            class="title"
                            style={`grid-area: ${id};`}
                            onkeydown={(e) =>
                                (e.key === "Enter" || e.key === " ") &&
                                console.log("No keyboard allowed sorry")}
                        >
                            <div class="poster">
                                <img
                                    src={`https://media.${$domain}/units/${unit}/poster.webp`}
                                    alt="poster"
                                />
                                <div class="poster_dsc">
                                    <p class="poster_dsc_text">{dsc}</p>
                                    <div class="poster_next">
                                        <p>Далее:</p>
                                        <p>Серия {num} -</p>
                                        <div class="poster_next_ctrl">
                                            <button>
                                                <img
                                                    src={`https://media.${$domain}/icons/left.svg`}
                                                    alt="<"
                                                />
                                            </button>
                                            <button>
                                                <img
                                                    src={`https://media.${$domain}/icons/left.svg`}
                                                    alt=">"
                                                />
                                            </button>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    {:else}
                        <div
                            role="button"
                            tabindex="0"
                            class="title"
                            style={`grid-area: ${id};`}
                            onkeydown={(e) =>
                                (e.key === "Enter" || e.key === " ") &&
                                console.log("No keyboard allowed sorry")}
                        >
                            <div class="poster">
                                <img
                                    src={`https://media.${$domain}/units/${id}/poster.webp`}
                                    alt="poster"
                                    class="episodeless"
                                />
                                <div class="poster_dsc">
                                    <p class="poster_dsc_text">{dsc}</p>
                                    <div class="poster_next">
                                        <p>Нет эпизодов</p>
                                    </div>
                                </div>
                            </div>
                        </div>
                    {/if}
                {/each}
                <div
                    class="placeholder"
                    style="height: {256 - columnOffsets[i]}px"
                ></div>
            </div>
        {/each}
    </div>
</main>

<style>
    main {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
    }

    button {
        outline: none;
        border: none;
        background: none;
    }

    p {
        margin: 0px;
    }

    h3 {
        color: white;
        pointer-events: none;
        font-weight: lighter;
        margin-top: 16px;
        margin-bottom: 4px;
    }

    rt {
        font-size: 0.5em;
        vertical-align: baseline;
    }

    span {
        display: ruby;
        color: gray;
        line-height: 0px;
        cursor: help;
        transition: color 0.2s ease;
    }

    span:hover {
        color: lightgray;
    }

    .columns {
        display: flex;
        flex-direction: row;
        gap: 32px;
    }

    .column {
        display: flex;
        flex-direction: column;
        gap: 32px;
        overflow: scroll;
    }

    .title {
        display: flex;
        flex-direction: column;
        align-items: start;
        justify-content: start;
    }

    .placeholder {
        background-color: #111111;
    }

    .poster {
        width: 192px;
        aspect-ratio: 210 / 297;
        display: inline-block;
        position: relative;
        cursor: pointer;
    }

    .poster img {
        width: 100%;
        height: 100%;
        transition: filter 0.4s ease;
    }

    .poster_dsc {
        max-height: calc(100% - 24px);
        max-width: calc(100% - 24px);
        position: absolute;
        top: 0;
        left: 0;
        justify-content: space-between;
        margin: 12px;
        text-shadow: 0 2px 6px rgba(0, 0, 0, 0.8);
        opacity: 0;
        overflow: hidden;
        transition: opacity 0.4s ease;
    }

    .poster_dsc_text {
        overflow-y: auto;
    }

    .poster_next_ctrl {
        justify-content: space-between;
    }

    .poster:hover img {
        filter: blur(8px);
    }

    .poster:hover .poster_dsc {
        opacity: 1;
    }

    .episodeless {
        filter: grayscale(100%);
    }
</style>
