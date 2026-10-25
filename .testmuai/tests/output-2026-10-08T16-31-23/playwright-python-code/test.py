import os
import testmu
from testmu import expect, var, set_var
from playwright.async_api import Page

testmu.configure(
    build="7beaeb9b-ba82-400e-aa3e-30aa5f1cdc7f",
    name="Build a Web App for Trading",
    tc_id="TC-3",
    network=os.getenv("NETWORK", "false").lower() == "true",
    auto_heal_version="AH2",
    default_action_timeout_ms=60000,
    default_navigation_timeout_ms=60000,
    kane_run_v4=True,
)

@testmu.test
async def test(page: Page):
    async with testmu.step('Navigate to https://www.google.com', instruction_id='fdc6aa0c-96b5-43d3-a025-ec1b48f6d65d'):
        await page.goto("https://www.google.com")
    
    async with testmu.step('Typing Build a web app for trading into the Google search box', instruction_id='e8249250-c983-424e-a386-9ec170f8090f'):
        element_0 = page.locator("internal:role=combobox[name=\"Rech.\"i]")
        
        try:
            await element_0.click(timeout=2000)
        except Exception:
            pass
        await element_0.fill("Build a web app for trading")
    
    async with testmu.step('Pressing Enter key to submit the Google search', instruction_id='aa52e058-3880-4e10-9c07-4b41759842f8'):
        await page.wait_for_timeout(500)
        await page.keyboard.press('Enter')
    
    async with testmu.step('Clicking the first search result link for the AI trading web app article', instruction_id='e8c1760f-fd21-4910-9880-705ad35e83e3'):
        _loc_1 = page.locator("internal:role=link[name=\"Build a Trading Web App Using\"i]")
        
        await _loc_1.click()
    
    async with testmu.step('Waiting for the queued plan to start', instruction_id='b5560a1b-4c17-47cc-8494-439062a9de2c'):
        await page.wait_for_timeout(1000)
    
    async with testmu.step('Waiting for the queued plan to start', instruction_id='d1b7d38e-354d-4fff-a0c5-28769058d021'):
        await page.wait_for_timeout(1000)
    
    async with testmu.step('Type "Create a responsive paper trading web app with a market dashboard, searchable stock watchlist, live-style price charts, portfolio balance and P&L, open positions, trade history, buy and sell order form, and risk metrics. Use a professional dark trading interface with mock market data." into "Décrivez votre idée idéale..."', instruction_id='81c41287-76b4-47fe-afeb-8e836391cf32'):
        element_1 = page.locator("section >> internal:has-text=\"Maison / Créateur d'\"i >> internal:attr=[placeholder=\"Décrivez votre idée idéale...\"i]")
        
        try:
            await element_1.click(timeout=2000)
        except Exception:
            pass
        await element_1.fill("Create a responsive paper trading web app with a market dashboard, searchable stock watchlist, live-style price charts, portfolio balance and P&L, open positions, trade history, buy and sell order form, and risk metrics. Use a professional dark trading interface with mock market data.")


if __name__ == "__main__":
    testmu.run(test)