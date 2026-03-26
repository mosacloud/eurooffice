import { test, expect } from '@playwright/test';

const EXAMPLE_PATH = '/example/';

const EDITOR_TYPES = [
  { label: 'Document',     selector: 'a.try-editor.word',  fileExt: 'docx' },
  { label: 'Spreadsheet',  selector: 'a.try-editor.cell',  fileExt: 'xlsx' },
  { label: 'Presentation', selector: 'a.try-editor.slide', fileExt: 'pptx' },
] as const;

test.describe('Example page - Create new', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(EXAMPLE_PATH);
    await expect(page).toHaveTitle(/ONLYOFFICE|euro-office/i);
  });

  for (const editor of EDITOR_TYPES) {
    test(`Create new ${editor.label}`, async ({ page }) => {
      // Register the new-tab handler BEFORE clicking so the event is not missed
      const newPagePromise = page.context().waitForEvent('page');

      await page.click(editor.selector);

      const editorPage = await newPagePromise;

      // The page opens as about:blank then navigates to the editor URL.
      // Wait for the URL to match the editor route before asserting content.
      await editorPage.waitForURL(/\/example\/editor/);
      await editorPage.waitForLoadState('domcontentloaded');

      // 1. URL contains the correct file extension in the fileName param
      await expect(editorPage).toHaveURL(new RegExp(`\\.${editor.fileExt}`));

      // 2. DocsAPI replaces the #iframeEditor mount point with an <iframe name="frameEditor">.
      //    Assert that iframe is present and its src points to the document editor app.
      const editorIframe = editorPage.locator('iframe[name="frameEditor"]');
      await expect(editorIframe).toBeAttached({ timeout: 15_000 });
      await expect(editorIframe).toHaveAttribute('src', /documenteditor|spreadsheeteditor|presentationeditor/);
    });
  }
});
