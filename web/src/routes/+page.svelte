<script lang="ts">
  let domain = window.location.hostname.split(".").slice(-2).join(".");

  type Word = {
    lang: string;

    word: {
      id: number;
      text: string;
      extra: Record<string, string>;
      mastery: number;
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

    fetch(url, {
      method: "GET",
      credentials: "include",
    })
      .then((res) => {
        if (res.status === 401) {
          window.location.href = `https://auth.${domain}/with/google`;
          return;
        }

        if (!res.ok) throw new Error("Request error");

        return res.json();
      })
      .then((data: Word) => {
        if (!data) return;

        showAnswer = false;
        winfo = data as Word;
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
            mastery: 0,
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

    const url = new URL(`https://api.${domain}/result`);

    fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        wid: winfo.word.id,
        time: responseTime,
      }),
      credentials: "include",
    })
      .then((res) => {
        if (res.status === 401) {
          window.location.href = `https://auth.${domain}/with/google`;
          return;
        }

        if (!res.ok) throw new Error("Request error");

        return res.json();
      })
      .then((data: Word) => {
        if (!data) return;

        showAnswer = false;
        winfo = data as Word;
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
            mastery: 0,
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

  function handleKeydown(event: KeyboardEvent): void {
    const { code } = event;

    if (!winfo) return;

    if (!showAnswer) {
      if (code === "Space" || code === "Enter") {
        event.preventDefault();
        /*
        if (timeoutId) {
          clearTimeout(timeoutId);
          timeoutId = null;
        }
        */
        responseTime = (performance.now() - startTime) / 1000;

        showAnswer = true;
      }
    } else {
      if (code === "Space" || code === "Enter") {
        event.preventDefault();
        submitResult();
      }

      if (code === "Escape" || code === "Backspace" || code === "KeyF") {
        event.preventDefault();
        responseTime = 10;
        submitResult();
      }
    }
  }

  function handleLeft() {
    if (!winfo) return;

    if (!showAnswer) {
      responseTime = (performance.now() - startTime) / 1000;
      showAnswer = true;
    } else {
      responseTime = 10;
      submitResult();
    }
  }

  function handleRight() {
    if (!winfo) return;

    if (!showAnswer) {
      responseTime = (performance.now() - startTime) / 1000;
      showAnswer = true;
    } else {
      submitResult();
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
      /*
      if (timeoutId) {
        clearTimeout(timeoutId);
        timeoutId = null;
      }
      */
    };
  });
</script>

<main>
  {#if winfo}
    <div class="tapzones">
      <div class="zoneleft" on:click={handleLeft}>
        {#if !showAnswer}
          <p>Reveal</p>
          <p>(Space)</p>
        {:else}
          <p>Incorrect</p>
          <p>(Esc)</p>
        {/if}
      </div>
      <div class="zoneright" on:click={handleRight}>
        {#if !showAnswer}
          <p>Reveal</p>
          <p>(Space)</p>
        {:else}
          <p>Correct</p>
          <p>(Space)</p>
        {/if}
      </div>
    </div>
    <div class="learninfo">
      {#if winfo.lang === "ja"}
        <div
          class="exmpcon"
          class:expanded={showAnswer || winfo.word.mastery < 0.8}
        >
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
        <div
          class="wordcon"
          class:expanded={showAnswer || winfo.word.mastery < 0.8}
        >
          <h1>
            {#each parseJapanese(winfo.word.text, winfo.word.extra) as seg}
              {#if seg.furigana}
                <ruby>{seg.text}<rt>{seg.furigana}</rt></ruby>
              {:else}
                {seg.text}
              {/if}
            {/each}
          </h1>
        </div>
        <div class="trnscon" class:expanded={showAnswer}>
          <p>{winfo.senses.join("\n")}</p>
        </div>
      {:else}
        <div class="wordcon">
          <h1>{winfo.word.text}</h1>
          <h3>{winfo.example.text}</h3>
        </div>
        <div class="trnscon" class:expanded={showAnswer}>
          <p>{winfo.senses.join("\n")}</p>
        </div>
      {/if}
    </div>
  {/if}
</main>

<style>
  main {
    height: 100vh;
  }

  header {
    display: flex;
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
  }

  .tapzones {
    z-index: 1;
    position: fixed;
    inset: 0;
    display: grid;
    grid-template-columns: 50% 50%;
    grid-template-areas: "incorrect correct";
    pointer-events: none;
  }

  .zoneleft {
    grid-area: incorrect;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    pointer-events: all;
  }

  .zoneleft p {
    color: #44444444;
  }

  .zoneright {
    grid-area: correct;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    pointer-events: all;
  }

  .zoneright p {
    color: #44444444;
  }

  .learninfo {
    z-index: 2;
    min-height: 100%;
    display: grid;
    grid-template-rows: 40% 20% auto;
    grid-template-areas: "example" "word" "translation";
    justify-content: center;
    align-items: center;
  }

  .exmpcon {
    grid-area: example;
    min-height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: end;
  }

  .exmpcon h3 {
    min-height: 48px;
    display: flex;
    align-items: flex-end;
    margin-top: 0px;
    margin-bottom: 0px;
  }

  .exmpcon rt {
    margin-bottom: -39px;
    opacity: 0;
  }

  .exmpcon.expanded rt {
    margin-bottom: 0px;
    opacity: 1;
    transition:
      margin-bottom 0.2s ease,
      opacity 0.2s ease;
  }

  .wordcon {
    grid-area: word;
    min-height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }

  .wordcon h1 {
    min-height: 128px;
    display: flex;
    align-items: flex-end;
    margin-top: 0px;
    margin-bottom: 0px;
    font-size: 64px;
  }

  .wordcon rt {
    margin-bottom: -39px;
    opacity: 0;
  }

  .wordcon.expanded rt {
    margin-bottom: 0px;
    opacity: 1;
    transition:
      margin-bottom 0.2s ease,
      opacity 0.2s ease;
  }

  .trnscon {
    grid-area: translation;
    min-height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: start;
    gap: 16px;
  }

  .trnscon p {
    font-size: 24px;
    text-align: center;
    white-space: pre-line;
    opacity: 0;
    transition: opacity 0s;
    margin: 0px;
  }

  .trnscon.expanded p {
    opacity: 1;
    transition: opacity 0.2s ease-in-out;
  }
</style>
