window.__ModuleLoader__.load({
	id: "cfg-theme",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		/** Cordis plugin name; also the bundle id the host serves. */
		const name = "cfg-theme";
		/** Required services: none — the override is a document-level stylesheet. */
		const inject = [];
		/** Tag identity, mirroring the bundled-sheet convention of the shipped packages. */
		const STYLE_SOURCE = "cfg-theme/theme.css";
		/**
		* The cfg-rendered token override. Its selectors outrank the shipped
		* sheets (html body = 0,0,2 over body = 0,0,1; html body[data-ds-dark-theme]
		* = 0,1,2 over body[data-ds-dark-theme] = 0,1,1), and because the alias
		* layer resolves through var() at its use site, re-pointing the static
		* layer here reaches every surface the shipped palette reached.
		*/
		const css = `
/* ---------------------------------------------------------------------------
   Light — Catppuccin Latte. Canvas is latte base; surfaces walk down the Latte
   grey ramp; text walks up from dimmed (subtext0) to primary (text).
   --------------------------------------------------------------------------- */
html body {
  --dsw-static-amber-100: color-mix(in srgb, #df8e1d 18%, #eff1f5);
  --dsw-static-amber-400: color-mix(in srgb, #df8e1d 72%, #eff1f5);
  --dsw-static-amber-500: color-mix(in srgb, #df8e1d 74%, #4c4f69);
  --dsw-static-amber-600: color-mix(in srgb, #fe640b 76%, #4c4f69);
  --dsw-static-amber-900: color-mix(in srgb, #fe640b 55%, #4c4f69);

  --dsw-static-blue-50: color-mix(in srgb, #8839ef 10%, #eff1f5);
  --dsw-static-blue-50p: color-mix(in srgb, #8839ef 12%, #eff1f5);
  --dsw-static-blue-75: color-mix(in srgb, #8839ef 16%, #eff1f5);
  --dsw-static-blue-100: color-mix(in srgb, #8839ef 22%, #eff1f5);
  --dsw-static-blue-300: color-mix(in srgb, #8839ef 42%, #eff1f5);
  --dsw-static-blue-400: #8839ef;
  --dsw-static-blue-450: #8839ef;
  --dsw-static-blue-500: #8839ef;
  --dsw-static-blue-600: color-mix(in srgb, #8839ef 70%, #eff1f5);
  --dsw-static-blue-800: color-mix(in srgb, #8839ef 45%, #eff1f5);
  --dsw-static-blue-900: #8839ef;
  --dsw-static-blue-950: color-mix(in srgb, #8839ef 25%, #eff1f5);

  --dsw-static-deepseek-50: color-mix(in srgb, #8839ef 9%, #eff1f5);
  --dsw-static-deepseek-100: color-mix(in srgb, #8839ef 16%, #eff1f5);
  --dsw-static-deepseek-200: color-mix(in srgb, #8839ef 26%, #eff1f5);
  --dsw-static-deepseek-300: color-mix(in srgb, #8839ef 40%, #eff1f5);
  --dsw-static-deepseek-400: #8839ef;
  --dsw-static-deepseek-450: #8839ef;
  --dsw-static-deepseek-500: #8839ef;
  --dsw-static-deepseek-600: color-mix(in srgb, #8839ef 55%, #eff1f5);
  --dsw-static-deepseek-700-delete: color-mix(in srgb, #8839ef 45%, #eff1f5);
  --dsw-static-deepseek-800: color-mix(in srgb, #8839ef 35%, #eff1f5);
  --dsw-static-deepseek-900: color-mix(in srgb, #8839ef 30%, #eff1f5);

  --dsw-static-green-100: color-mix(in srgb, #40a02b 16%, #eff1f5);
  --dsw-static-green-400: color-mix(in srgb, #40a02b 65%, #eff1f5);
  --dsw-static-green-500: color-mix(in srgb, #40a02b 78%, #4c4f69);
  --dsw-static-green-900: color-mix(in srgb, #40a02b 55%, #4c4f69);

  --dsw-static-neutral-00: #eff1f5;
  --dsw-static-neutral-50: #e6e9ef;
  --dsw-static-neutral-100: #dce0e8;
  --dsw-static-neutral-150: #ccd0da;
  --dsw-static-neutral-200: #ccd0da;
  --dsw-static-neutral-250: #bcc0cc;
  --dsw-static-neutral-300: #bcc0cc;
  --dsw-static-neutral-400: #9ca0b0;
  --dsw-static-neutral-500: #7c7f93;
  --dsw-static-neutral-550: #6c6f85;
  --dsw-static-neutral-600: #5c5f77;
  --dsw-static-neutral-700: #4c4f69;
  --dsw-static-neutral-800: #dce0e8;
  --dsw-static-neutral-850: #e6e9ef;
  --dsw-static-neutral-900: #eff1f5;
  --dsw-static-neutral-1000: #eff1f5;

  --dsw-static-neutral-bluish-00: #eff1f5;
  --dsw-static-neutral-bluish-50: #e6e9ef;
  --dsw-static-neutral-bluish-60: #dce0e8;
  --dsw-static-neutral-bluish-75: #ccd0da;
  --dsw-static-neutral-bluish-100: #bcc0cc;
  --dsw-static-neutral-bluish-150: #ccd0da;
  --dsw-static-neutral-bluish-200: #acb0be;
  --dsw-static-neutral-bluish-300: #8c8fa1;
  --dsw-static-neutral-bluish-400: #8c8fa1;
  --dsw-static-neutral-bluish-500: #7c7f93;
  --dsw-static-neutral-bluish-600: #6c6f85;
  --dsw-static-neutral-bluish-700: #5c5f77;
  /* The light theme's two dark chips: toast fill and tooltip fill. The tooltip
     renders its text in --dsw-static-neutral-bluish-00 (see the frontend
     bundle's .bubble rule), so its fill must stay dark in both palettes. */
  --dsw-static-neutral-bluish-750: #7c7f93;
  --dsw-static-neutral-bluish-800: #4c4f69;
  --dsw-static-neutral-bluish-850: #4c4f69;
  --dsw-static-neutral-bluish-875: #dce0e8;
  --dsw-static-neutral-bluish-900: #dce0e8;
  --dsw-static-neutral-bluish-950: #6c6f85;
  --dsw-static-neutral-bluish-1000: #4c4f69;

  --dsw-static-red-50: color-mix(in srgb, #d20f39 10%, #eff1f5);
  --dsw-static-red-100: color-mix(in srgb, #d20f39 16%, #eff1f5);
  --dsw-static-red-400: color-mix(in srgb, #d20f39 70%, #eff1f5);
  --dsw-static-red-500: #d20f39;
  --dsw-static-red-600: #d20f39;
  --dsw-static-red-900: color-mix(in srgb, #d20f39 55%, #4c4f69);

  /* The alias layer's only literals. The other 85 alias tokens are var()
     indirections and are deliberately not restated here. */
  --dsw-alias-brand-primary: #8839ef;
  --dsw-alias-brand-text: #8839ef;
  --dsw-alias-brand-primary-new-colorprimary-new-color: #8839ef;
  --dsw-alias-button-primary-hover: color-mix(in srgb, #8839ef 85%, #4c4f69);
  /* The composer's send button paints a hardcoded white glyph on this fill
     (.uV2eYG_primary in ui-conversation). Latte's accent is already the deep
     step, so the fill is the accent itself and the hover deepens it. */
  --dsw-alias-button-info-fill: #8839ef;
  --dsw-alias-button-info-hover: color-mix(in srgb, #8839ef 85%, #4c4f69);
}

/* ---------------------------------------------------------------------------
   Dark — the active cfg flavor (mocha). Canvas is base; the sidebar and
   code blocks sit on mantle below it; raised surfaces walk surface0 → surface1
   → surface2 → overlay0.
   --------------------------------------------------------------------------- */
html body[data-ds-dark-theme] {
  --dsw-static-amber-100: color-mix(in srgb, #f9e2af 18%, #1e1e2e);
  --dsw-static-amber-400: color-mix(in srgb, #f9e2af 55%, #1e1e2e);
  --dsw-static-amber-500: #f9e2af;
  --dsw-static-amber-600: #fab387;
  --dsw-static-amber-900: color-mix(in srgb, #f9e2af 16%, #1e1e2e);

  --dsw-static-blue-50: color-mix(in srgb, #cba6f7 12%, #1e1e2e);
  --dsw-static-blue-50p: color-mix(in srgb, #cba6f7 16%, #1e1e2e);
  --dsw-static-blue-75: color-mix(in srgb, #cba6f7 22%, #1e1e2e);
  --dsw-static-blue-100: color-mix(in srgb, #cba6f7 30%, #1e1e2e);
  --dsw-static-blue-300: color-mix(in srgb, #cba6f7 60%, #1e1e2e);
  --dsw-static-blue-400: #cba6f7;
  --dsw-static-blue-450: #cba6f7;
  --dsw-static-blue-500: color-mix(in srgb, #cba6f7 85%, #11111b);
  --dsw-static-blue-600: color-mix(in srgb, #cba6f7 65%, #1e1e2e);
  --dsw-static-blue-800: color-mix(in srgb, #cba6f7 30%, #1e1e2e);
  --dsw-static-blue-900: #cba6f7;
  --dsw-static-blue-950: color-mix(in srgb, #cba6f7 18%, #1e1e2e);

  --dsw-static-deepseek-50: color-mix(in srgb, #cba6f7 10%, #1e1e2e);
  --dsw-static-deepseek-100: color-mix(in srgb, #cba6f7 16%, #1e1e2e);
  --dsw-static-deepseek-200: color-mix(in srgb, #cba6f7 34%, #1e1e2e);
  --dsw-static-deepseek-300: color-mix(in srgb, #cba6f7 55%, #1e1e2e);
  --dsw-static-deepseek-400: #cba6f7;
  --dsw-static-deepseek-450: #cba6f7;
  --dsw-static-deepseek-500: color-mix(in srgb, #cba6f7 80%, #11111b);
  --dsw-static-deepseek-600: color-mix(in srgb, #cba6f7 68%, #1e1e2e);
  --dsw-static-deepseek-700-delete: color-mix(in srgb, #cba6f7 52%, #1e1e2e);
  --dsw-static-deepseek-800: color-mix(in srgb, #cba6f7 22%, #1e1e2e);
  --dsw-static-deepseek-900: color-mix(in srgb, #cba6f7 12%, #1e1e2e);

  --dsw-static-green-100: color-mix(in srgb, #a6e3a1 18%, #1e1e2e);
  --dsw-static-green-400: color-mix(in srgb, #a6e3a1 70%, #1e1e2e);
  --dsw-static-green-500: #a6e3a1;
  --dsw-static-green-900: color-mix(in srgb, #a6e3a1 16%, #1e1e2e);

  --dsw-static-neutral-00: #cdd6f4;
  --dsw-static-neutral-50: #bac2de;
  --dsw-static-neutral-100: #a6adc8;
  --dsw-static-neutral-150: #9399b2;
  --dsw-static-neutral-200: #7f849c;
  --dsw-static-neutral-250: #6c7086;
  --dsw-static-neutral-300: #6c7086;
  --dsw-static-neutral-400: #7f849c;
  --dsw-static-neutral-500: #6c7086;
  --dsw-static-neutral-550: #6c7086;
  --dsw-static-neutral-600: #585b70;
  --dsw-static-neutral-700: #45475a;
  --dsw-static-neutral-800: #313244;
  --dsw-static-neutral-850: #313244;
  --dsw-static-neutral-900: #181825;
  --dsw-static-neutral-1000: #11111b;

  --dsw-static-neutral-bluish-00: #cdd6f4;
  --dsw-static-neutral-bluish-50: #cdd6f4;
  --dsw-static-neutral-bluish-60: #a6adc8;
  --dsw-static-neutral-bluish-75: #9399b2;
  --dsw-static-neutral-bluish-100: #9399b2;
  --dsw-static-neutral-bluish-150: #6c7086;
  --dsw-static-neutral-bluish-200: #6c7086;
  --dsw-static-neutral-bluish-300: #bac2de;
  --dsw-static-neutral-bluish-400: #a6adc8;
  --dsw-static-neutral-bluish-500: #9399b2;
  --dsw-static-neutral-bluish-600: #7f849c;
  --dsw-static-neutral-bluish-700: #45475a;
  --dsw-static-neutral-bluish-750: #45475a;
  --dsw-static-neutral-bluish-800: #45475a;
  --dsw-static-neutral-bluish-850: #313244;
  --dsw-static-neutral-bluish-875: color-mix(in srgb, #1e1e2e 55%, #313244);
  --dsw-static-neutral-bluish-900: #181825;
  --dsw-static-neutral-bluish-950: #1e1e2e;
  --dsw-static-neutral-bluish-1000: #11111b;

  --dsw-static-red-50: color-mix(in srgb, #f38ba8 12%, #1e1e2e);
  --dsw-static-red-100: color-mix(in srgb, #f38ba8 18%, #1e1e2e);
  --dsw-static-red-400: #f38ba8;
  --dsw-static-red-500: color-mix(in srgb, #f38ba8 80%, #11111b);
  --dsw-static-red-600: #f38ba8;
  --dsw-static-red-900: color-mix(in srgb, #f38ba8 16%, #1e1e2e);

  --dsw-alias-brand-primary: #cba6f7;
  --dsw-alias-brand-text: #cba6f7;
  --dsw-alias-brand-primary-new-colorprimary-new-color: #cba6f7;
  --dsw-alias-button-primary-hover: color-mix(in srgb, #cba6f7 80%, #11111b);
  /* Same white glyph, opposite step: the shipped dark theme pairs it with the
     bright brand step (deepseek-400, never -500), so this fill is the accent
     itself — the same value as --dsw-alias-brand-primary. The Latte reading
     used here before rendered as a second, deeper purple beside it. */
  --dsw-alias-button-info-fill: #cba6f7;
  --dsw-alias-button-info-hover: color-mix(in srgb, #cba6f7 85%, #1e1e2e);
}
`;
		/**
		* Mount the override: one plugin-owned style tag in head, removed on
		* dispose (and by the client HMR reload path, which drops every
		* style[data-plugin="cfg-theme"] before re-running this apply).
		* @param ctx - client cordis context.
		*/
		function apply(ctx) {
			ctx.effect(() => {
				const el = document.createElement("style");
				el.dataset.plugin = name;
				el.dataset.pluginCss = STYLE_SOURCE;
				el.textContent = css;
				document.head.append(el);
				return () => el.remove();
			}, "cfg-theme: Catppuccin palette override");
		}
		exports.apply = apply;
		exports.inject = inject;
		exports.name = name;
		return module.exports;
	}
});
