const HOST = "com.ytvlc.player";

chrome.action.onClicked.addListener(async () => {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const url = tab?.url || "";

  chrome.runtime.sendNativeMessage(HOST, { url }, (reply) => {
    if (chrome.runtime.lastError) {
      console.error("sendNativeMessage failed:", chrome.runtime.lastError.message);
      return;
    }
    console.log("native reply:", reply);
  });
});