<script lang="ts">
    let domain = window.location.hostname.split('.').slice(-2).join('.');

    type Word = {
        id: number;
        lang: string;
        word: string;
        example: string;
        sense: string;
    };

    let rescheck: boolean = $state(false);
    let winfo: Word | undefined = $state();
    let startTime = 0;
    let timeoutId: ReturnType<typeof setTimeout> | null = null;
    let normalizedTime: number = 1;

    function startAnswerTimer() {
        startTime = performance.now();

        timeoutId = setTimeout(() => {
            normalizedTime = 1;
            rescheck = true;
        }, 5000);
    }

    function fetchNewWord() {
        const url = new URL(`https://api.${$domain}/word`);

        fetch(url)
            .then((res) => {
                if (!res.ok) {
                    console.error("Request error");
                    return;
                }
                return res.json();
            })
            .then((data) => {
                winfo = data as Word;
                startAnswerTimer();
            })
            .catch((err) => {
                console.error("Ошибка:", err);
                winfo = {
                    id: 0,
                    word: "Ошибка подключения к серверу",
                    example:
                        "Проверьте свое подключение к интернету и обновите страницу",
                    sense: "Кто прочитал, тот остался без интернета",
                } satisfies Word;
            });
    }

    function submitResult(correct: boolean) {
        if (!winfo) return;

        fetch(`https://api.${$domain}/result`, {
            method: "POST",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({
                wordId: winfo.id,
                time: normalizedTime,
                correct,
            }),
        }).catch(console.error);
    }

    function handleKeydown(event: KeyboardEvent): void {
        const { code } = event;

        if (!rescheck) {
            if (code === "Space" || code === "Enter") {
                event.preventDefault();

                if (timeoutId) {
                    clearTimeout(timeoutId);
                    timeoutId = null;
                }

                const elapsed = performance.now() - startTime;
                normalizedTime = Math.min(elapsed / 5000, 1);

                rescheck = true;
            }
        } else {
            if (code === "Space" || code === "Enter") {
                event.preventDefault();
                submitResult(true);
                fetchNewWord();
            }

            if (code === "Escape" || code === "Backspace") {
                event.preventDefault();
                submitResult(false);
                fetchNewWord();
            }
        }
    }

    $effect(() => {
        fetchNewWord();

        window.addEventListener("keydown", handleKeydown);

        return () => {
            window.removeEventListener("keydown", handleKeydown);
            if (timeoutId) {
                clearTimeout(timeoutId);
                timeoutId = null;
            }
        };
    });
</script>

<main>
    {#if winfo}
        {#if winfo.lang === "ja"}
            <div class="wordcon" class:rescheck>
                <h1>
                    {#each winfo.word.split("  ") as unit}
                        {@const [word, sense = ""] = unit.split("|")}
                        <span title={sense}>
                            {#each word.split("]") as part}
                                {@const [kanji, furigana = ""] = part.split("[")}
                                {kanji}<rt>{furigana}</rt>
                            {/each}
                        </span>
                    {/each}
                </h1>
                <h3>
                    {#each winfo.example.split("  ") as unit}
                        {@const [word, sense = ""] = unit.split("|")}
                        <span title={sense}>
                            {#each word.split("]") as part}
                                {@const [kanji, furigana = ""] = part.split("[")}
                                {kanji}<rt>{furigana}</rt>
                            {/each}
                        </span>
                    {/each}
                </h3>
            </div>
            <div class="trnscon" class:showed={rescheck}>
                <p>{winfo.sense}</p>
            </div>
        {:else}
            <div class="wordcon" class:rescheck>
                <h1>{winfo.word}</h1>
                <h3>{winfo.example}</h3>
            </div>
            <div class="trnscon" class:showed={rescheck}>
                <p>{winfo.sense}</p>
            </div>
        {/if}
    {/if}
</main>

<style>
    h1 {
        font-size: 64px;
        margin-top: -36px;
        margin-bottom: 0px;
    }

    h2 {
        font-size: 36px;
        opacity: 0;
        transition: opacity 0s;
        margin: 0px;
    }

    .expanded h2 {
        opacity: 1;
        transition: opacity 0.2s ease-in-out;
    }

    header {
        display: flex;
        flex-direction: row;
        justify-content: space-between;
        align-items: center;
    }

    main {
        flex-grow: 1;
        display: grid;
        grid-template-rows: 3fr 3fr 4fr;
        grid-template-areas: "." "question" "answer";
        justify-content: center;
        align-items: center;
    }

    .wordcon {
        height: 72px;
        grid-area: question;
        display: flex;
        flex-direction: column;
        justify-content: space-between;
        align-items: center;
        transition: height 0s;
    }

    .expanded {
        height: 128px;
        transition: height 0.2s ease-in-out;
    }

    .trnscon {
        height: 100%;
        grid-area: answer;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 16px;
    }

    .trnscon p {
        font-size: 24px;
        white-space: pre-line;
        opacity: 0;
        transition: opacity 0s;
        margin: 0px;
    }

    .showed p {
        opacity: 1;
        transition: opacity 0.2s ease-in-out;
    }
</style>
