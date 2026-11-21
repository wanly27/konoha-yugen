(() => {
  const cfg = window.ELECTION_CONFIG || {};
  const form = document.getElementById("voteForm");
  const status = document.getElementById("status");
  const button = document.getElementById("submitBtn");
  const customWrap = document.getElementById("customWrap");
  const customInput = document.getElementById("customCandidate");
  const featuredName = document.getElementById("featuredName");

  featuredName.textContent = cfg.FEATURED_CANDIDATE || "Предложенный кандидат";

  function selectedChoice() {
    return form.querySelector('input[name="choice"]:checked')?.value || "featured";
  }

  function updateChoice() {
    const custom = selectedChoice() === "custom";
    customWrap.hidden = !custom;
    customInput.required = custom;
  }

  form.querySelectorAll('input[name="choice"]').forEach(el => el.addEventListener("change", updateChoice));
  updateChoice();

  function show(message, type) {
    status.textContent = message;
    status.className = "status " + (type || "");
  }

  function isValidSteamId(value) {
    return /^(STEAM_[0-5]:[01]:[0-9]{1,12}|7656119[0-9]{10})$/i.test(value);
  }

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    show("", "");

    const nickname = document.getElementById("nickname").value.trim();
    const steamId = document.getElementById("steamId").value.trim().toUpperCase();
    const choice = selectedChoice();
    const candidate = choice === "featured"
      ? String(cfg.FEATURED_CANDIDATE || "").trim()
      : customInput.value.trim();

    if (nickname.length < 3 || nickname.length > 24) {
      show("Ник должен содержать от 3 до 24 символов.", "error");
      return;
    }
    if (!isValidSteamId(steamId)) {
      show("Укажи корректный SteamID (например, STEAM_0:1:12345678 или 76561198000000000).", "error");
      return;
    }
    if (!candidate || candidate.length > 60) {
      show("Укажи имя кандидата (не более 60 символов).", "error");
      return;
    }
    if (!cfg.SUPABASE_URL || cfg.SUPABASE_URL.startsWith("ВСТАВЬТЕ_") ||
        !cfg.SUPABASE_ANON_KEY || cfg.SUPABASE_ANON_KEY.startsWith("ВСТАВЬТЕ_")) {
      show("Сначала добавь URL и публичный ключ Supabase в файл config.js.", "error");
      return;
    }
    if (!window.supabase?.createClient) {
      show("Не удалось загрузить библиотеку голосования. Обнови страницу и попробуй снова.", "error");
      return;
    }

    button.disabled = true;
    button.textContent = "Печать ставится…";
    try {
      const client = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_ANON_KEY);
      const { error } = await client.from("votes").insert({
        nickname,
        steam_id: steamId,
        candidate_name: candidate,
        candidate_type: choice
      });

      if (error) {
        if (error.code === "23505") {
          const msg = (error.message || "").includes("steam_id")
            ? "С этого SteamID голос уже был отправлен."
            : "С этого игрового ника или SteamID голос уже был отправлен.";
          show(msg, "error");
        } else if (error.code === "23514") {
          show("Неверный формат SteamID или ника.", "error");
        } else if (error.code === "42501") {
          show("Голосование закрыто или запрос не разрешён.", "error");
        } else {
          console.error(error);
          show("Не удалось сохранить голос. Проверь настройки Supabase и попробуй позже.", "error");
        }
      } else {
        show("Твой голос запечатан! Спасибо за участие в судьбе Конохи.", "success");
        form.reset();
        updateChoice();
      }
    } catch (err) {
      console.error(err);
      show("Ошибка соединения. Попробуй ещё раз позже.", "error");
    } finally {
      button.disabled = false;
      button.textContent = "Поставить печать и проголосовать";
    }
  });
})();
