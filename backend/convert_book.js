const fs = require('fs');
const path = require('path');

const mdPath = path.join(__dirname, '../GP_BOOK.md');
const htmlPath = path.join(__dirname, '../GP_BOOK_Detailed.html');

const template = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>iPARK - Final Graduation Project Thesis</title>
    <!-- Parse markdown locally in the browser -->
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <style>
        body { font-family: 'Times New Roman', serif; line-height: 1.6; color: #333; max-width: 1000px; margin: 40px auto; padding: 60px; background-color: #fff; box-shadow: 0 0 20px rgba(0,0,0,0.1); }
        h1 { font-family: 'Arial', sans-serif; color: #2c3e50; border-bottom: 4px solid #2c3e50; padding-bottom: 15px; text-align: center; text-transform: uppercase; letter-spacing: 2px; font-size: 2.2em; }
        h2 { font-family: 'Arial', sans-serif; color: #2980b9; margin-top: 60px; border-bottom: 2px solid #3498db; padding-bottom: 10px; text-transform: uppercase; page-break-before: always; }
        h3 { font-family: 'Arial', sans-serif; color: #16a085; margin-top: 35px; border-left: 6px solid #16a085; padding-left: 15px; }
        h4 { font-family: 'Arial', sans-serif; color: #2c3e50; margin-top: 25px; font-weight: bold; font-style: italic; }
        p, li { font-size: 1.15em; margin-bottom: 18px; text-align: justify; }
        ul, ol { padding-left: 35px; font-size: 1.15em; }
        table { width: 100%; border-collapse: collapse; margin: 30px 0; font-size: 1em; }
        th, td { border: 1px solid #7f8c8d; padding: 15px; text-align: left; vertical-align: top; }
        th { background-color: #f2f2f2; font-weight: bold; color: #2c3e50; text-transform: uppercase; font-size: 0.9em; }
        pre { background-color: #2d3436; color: #dfe6e9; padding: 25px; border-radius: 8px; overflow-x: auto; font-family: 'Consolas', monospace; font-size: 0.95em; line-height: 1.4; }
        code { background-color: #f1f2f6; color: #e17055; padding: 2px 5px; border-radius: 4px; font-family: 'Consolas', monospace; }
        hr { border: 0; border-top: 3px solid #eee; margin: 70px 0; }
        .mermaid { display: flex; justify-content: center; margin: 30px 0; }
        em { color: #7f8c8d; }
    </style>
</head>
<body>
    <div id="content"></div>

    <script>
        // Initialize Mermaid
        mermaid.initialize({ startOnLoad: true, theme: 'default' });
        
        // Raw markdown injected from script
        const rawMarkdown = \`RAW_MARKDOWN_PLACEHOLDER\`;

        // Render Markdown to HTML using marked
        document.getElementById('content').innerHTML = marked.parse(rawMarkdown);

        // Convert code blocks with 'language-mermaid' to div class='mermaid' so Mermaid.js can render them
        document.querySelectorAll('pre code.language-mermaid').forEach((block) => {
            const container = document.createElement('div');
            container.className = 'mermaid';
            container.textContent = block.textContent;
            block.parentNode.replaceWith(container);
        });

        // Tell mermaid to render the new diagrams
        mermaid.init(undefined, document.querySelectorAll('.mermaid'));
    </script>
</body>
</html>`;

try {
    const mdContent = fs.readFileSync(mdPath, 'utf8');
    // Escape backticks, backslashes, and dollar signs for JS template literal
    const escapedMd = mdContent.replace(/\\/g, '\\\\').replace(/\`/g, '\\`').replace(/\$/g, '\\$');
    const finalHtml = template.replace('RAW_MARKDOWN_PLACEHOLDER', escapedMd);

    fs.writeFileSync(htmlPath, finalHtml);
    console.log('Successfully generated GP_BOOK_Detailed.html from GP_BOOK.md');
} catch (error) {
    console.error('Error generating HTML:', error);
}
