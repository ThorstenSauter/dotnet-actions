using Microsoft.Playwright;

namespace SelfTest.E2E;

[TestClass]
public sealed class BrowserTests
{
    [TestMethod]
    public async Task Chromium_RendersPage()
    {
        using var playwright = await Playwright.CreateAsync();
        await using var browser = await playwright.Chromium.LaunchAsync();
        var page = await browser.NewPageAsync();

        await page.SetContentAsync("<title>Self-test</title>");

        Assert.AreEqual("Self-test", await page.TitleAsync());
    }
}
