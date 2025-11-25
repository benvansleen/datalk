<script>
  import hljs from 'highlight.js/lib/core';
  import markdown from 'highlight.js/lib/languages/markdown';
  import python from 'highlight.js/lib/languages/python';
  import { afterUpdate, onMount } from 'svelte';
  import 'highlight.js/styles/base16/gruvbox-dark-medium.css';
  import '@fontsource/victor-mono/400.css';
  import '@fontsource/iosevka-aile/300.css';

  hljs.registerLanguage('markdown', markdown);
  hljs.registerLanguage('python', python);
  onMount(() => {
    hljs.highlightAll();
  });
</script>

<slot />

<style>
  :global(body) {
    font-family:
      'Iosevka Aile',
      system-ui,
      -apple-system,
      sans-serif;
  }
  :global(.markdown body) {
    line-height: 1.6;
    font-size: 1rem;
    color: #2d2d2d;
    max-width: 100%;
    overflow-wrap: break-word;
  }
  :global(.markdown h1) {
    font-size: 1.8rem;
    font-weight: bold;
  }
  :global(.markdown h2) {
    font-size: 1.4rem;
    font-weight: bold;
  }
  :global(.markdown h3) {
    font-size: 1.2rem;
    font-weight: bold;
  }

  /* Paragraphs */
  :global(.markdown p) {
    margin: 0.8em 0;
  }

  /* Links */
  :global(.markdown a) {
    color: #4ea1ff;
    text-decoration: none;
  }
  :global(.markdown a:hover) {
    text-decoration: underline;
  }

  :global(.markdown ul ol) {
    margin: 0.8em 0;
    padding-left: 1.5em;
  }

  :global(.markdown li) {
    margin-top: 0.4em;
  }

  /* Inline code */
  :global(.markdown code) {
    background: #2f2f2f;
    padding: 0.1em 0.4em;
    border-radius: 4px;
    font-size: 0.95rem;
    font-family: 'Victor Mono', monospace;
    color: #bfbfbf;
  }

  /* Code blocks */
  :global(.markdown pre) {
    background: #1e1e1e !important;
    padding: 1rem;
    margin: 1em 0;
    border-radius: 6px;
    overflow-x: auto;
    border: 1px solid #2c2c2c;
  }

  :global(.markdown pre code) {
    background: none !important;
    padding: 0;
    font-size: 0.95rem;
  }

  /* Blockquotes (ChatGPT style) */
  :global(.markdown blockquote) {
    border-left: 4px solid #bfbfbf;
    padding-left: 1em;
    margin: 1em 0;
    color: #3a3a3a;
    font-style: italic;
  }

  /* Tables */
  /* Sleek tables inside markdown */
  :global(.markdown table) {
    border-collapse: collapse;
    width: 100%;
    margin: 1em 0;
    font-size: 0.95rem;
    overflow-x: auto;
    display: block;
  }

  :global(.markdown th, .markdown td) {
    padding: 0.4rem 0.6rem;
  }

  :global(.markdown th) {
    background: #bfbfbf;
  }

  :global(.markdown tr:nth-child(even) td) {
    background: #bfbfbf; /* light striping */
  }

  :global(.markdown tr:hover td) {
    background: #2d2d2d; /* subtle hover row */
    color: #bfbfbf;
  }

  /* Rounded corners without heavy borders */
  :global(.markdown table) {
    border-radius: 6px;
  }

  /* Make header corners rounded */
  :global(.markdown table thead tr:first-child th:first-child) {
    border-top-left-radius: 6px;
  }
  :global(.markdown table thead tr:first-child th:last-child) {
    border-top-right-radius: 6px;
  }

  /* Make footer corners rounded */
  :global(.markdown table tr:last-child td:first-child) {
    border-bottom-left-radius: 6px;
  }
  :global(.markdown table tr:last-child td:last-child) {
    border-bottom-right-radius: 6px;
  }

  /* Images */
  :global(.markdown img) {
    max-width: 100%;
    border-radius: 8px;
    margin: 1em 0;
  }
</style>
