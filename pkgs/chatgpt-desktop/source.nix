# Официальный Linux-сборник OpenAI (ChatGPT desktop = Chat + Work + Codex).
# URL у OpenAI НЕ версионированный (.../latest/...), поэтому хеш приходится
# пере-пинивать руками при каждом их релизе: ./update.sh
{
  version = "26.928.21956";

  sources = {
    x86_64-linux = {
      url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/latest/chatgpt_amd64.deb";
      hash = "sha256-msjQcRtGATaNSd7dv1Co/lI1jLYbbZ96XBi0HtRQCtg=";
    };
  };
}
