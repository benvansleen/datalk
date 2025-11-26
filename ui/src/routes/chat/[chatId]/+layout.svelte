<script>
  import hljs from 'highlight.js/lib/core';
  import markdown from 'highlight.js/lib/languages/markdown';
  import python from 'highlight.js/lib/languages/python';
  import sql from 'highlight.js/lib/languages/sql';
  import 'highlight.js/styles/base16/gruvbox-dark-medium.css';
  import '@fontsource/victor-mono/400.css';

  hljs.registerLanguage('markdown', markdown);
  hljs.registerLanguage('python', python);
  hljs.registerLanguage('sql', sql);
</script>

<slot />

<style>
  :global(.markdown body) {
    line-height: 1.6;
    font-size: 1rem;
    color: #2d2d2d;
    max-width: 100%;
    overflow-wrap: break-word;
  }
  :global(.markdown h1) {
    font-size: 1.4rem;
    font-weight: bold;
    margin-top: 1.5rem;
    margin-bottom: 0;
  }
  :global(.markdown h2) {
    font-size: 1.2rem;
    font-weight: bold;
    margin-top: 1.5rem;
    margin-bottom: 0;
  }
  :global(.markdown h3) {
    font-size: 1.1rem;
    font-weight: bold;
    margin-top: 1.5rem;
    margin-bottom: 0;
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

  :global(table) {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9rem;
    color: #333;
    background: white;
  }

  :global(thead) {
    background: #f5f5f7;
    text-align: left;
  }

  :global(th, td) {
    padding: 0.75rem 1rem;
    border-bottom: 1px solid #e5e7eb;
  }

  :global(th) {
    font-weight: 600;
    color: #1f2937;
  }

  :global(tbody tr:hover) {
    background: #f9fafb;
  }

  :global(tbody tr:last-child td) {
    border-bottom: none;
  }

  :global(table.striped tbody tr:nth-child(even)) {
    background: #fafafa;
  }

  :global(table.compact th, table.compact td) {
    padding: 0.5rem 0.75rem;
  }
  /* Images */
  :global(.markdown img) {
    max-width: 100%;
    border-radius: 8px;
    margin: 1em 0;
  }
</style>
