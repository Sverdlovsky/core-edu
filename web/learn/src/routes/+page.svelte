<script lang="ts">
  let domain = window.location.hostname.split(".").slice(-2).join(".");

  type Word = {
    lang: string;

    word: {
      id: number;
      text: string;
      extra: Record<string, string>;
    };

    example: {
      id: number;
      text: string;
      extra: Record<string, string>;
    };

    senses: string[];
  };

  let showAnswer: boolean = $state(false);
  let winfo: Word | undefined = $state();
  //let timeoutId: ReturnType<typeof setTimeout> | null = null;
  let startTime: number = 0;
  let responseTime: number = 0;

  function fetchNewWord() {
    const url = new URL(`https://api.${domain}/word`);

    fetch(url)
      .then((res) => {
        if (!res.ok) throw new Error("Request error");
        return res.json();
      })
      .then((data: Word) => {
        winfo = data as Word;
        showAnswer = false;
        startTime = performance.now();
        /*
        timeoutId = setTimeout(() => {
          normalizedTime = 1;
          rescheck = true;
        }, 5000);
        */
      })
      .catch((err) => {
        console.error(err);
        winfo = {
          lang: "en",
          word: {
            id: 0,
            text: "Connection error",
            extra: {},
          },
          example: {
            id: 0,
            text: "Check yout internet connection and reload page",
            extra: {},
          },
          senses: ["Enough internet for today"],
        } satisfies Word;
      });
  }

  function submitResult() {
    if (!winfo) return;

    fetch(`https://api.${domain}/result`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        wordId: winfo.word.id,
        time: responseTime,
      }),
    }).catch(console.error);
  }

  function handleKeydown(event: KeyboardEvent): void {
    const { code } = event;

    if (!showAnswer) {
      if (code === "Space" || code === "Enter") {
        event.preventDefault();
        /*
        if (timeoutId) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
        */
        responseTime = performance.now() - startTime;

        showAnswer = true;
      }
    } else {
      if (code === "Space" || code === "Enter") {
        event.preventDefault();
        submitResult();
        fetchNewWord();
      }

      if (code === "Escape" || code === "Backspace" || code === "KeyF") {
        event.preventDefault();
        responseTime = 10;
        submitResult();
        fetchNewWord();
      }
    }
  }

  type Segment = {
    text: string;
    furigana?: string;
  };

  export function parseJapanese(
    text: string,
    extra: Record<string, string>,
  ): Segment[] {
    const result: Segment[] = [];

    const keys = Object.keys(extra).sort((a, b) => b.length - a.length);

    let i = 0;

    while (i < text.length) {
      let matched = false;

      for (const key of keys) {
        if (text.startsWith(key, i)) {
          result.push({
            text: key,
            furigana: extra[key],
          });
          i += key.length;
          matched = true;
          break;
        }
      }

      if (!matched) {
        result.push({
          text: text[i],
        });
        i++;
      }
    }

    return result;
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
      <div class="wordcon" class:showAnswer>
        <h1>
          {#each parseJapanese(winfo.word.text, winfo.word.extra) as seg}
            {#if seg.furigana}
              <ruby>{seg.text}<rt>{seg.furigana}</rt></ruby>
            {:else}
              {seg.text}
            {/if}
          {/each}
        </h1>
        <h3>
          {#each parseJapanese(winfo.example.text, winfo.example.extra) as seg}
            {#if seg.furigana}
              <ruby>{seg.text}<rt>{seg.furigana}</rt></ruby>
            {:else}
              {seg.text}
            {/if}
          {/each}
        </h3>
      </div>
      <div class="trnscon" class:showed={showAnswer}>
        <p>{winfo.senses.join("\n")}</p>
      </div>
    {:else}
      <div class="wordcon" class:showAnswer>
        <h1>{winfo.word.text}</h1>
        <h3>{winfo.example.text}</h3>
      </div>
      <div class="trnscon" class:showed={showAnswer}>
        <p>{winfo.senses.join("\n")}</p>
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
