-- Planescape: Torment EE config overrides
-- Managed by dotfiles: games/planescape-torment-ee/baldur.lua
-- Note: the game rewrites this file on clean shutdown. In-game setting
-- changes will surface as diffs in the dotfiles repo.

-- Display — game-side fullscreen. The launcher (pst-ee-launch.sh) renders
-- gamescope 1:1 at monitor native (3440x1440 on this machine), so the game
-- needs to request fullscreen to fill that surface rather than opening a
-- 1024x768 window inside it.
SetPrivateProfileString('Program Options','Full Screen','1')
SetPrivateProfileString('Program Options','Maximize Window','1')

-- Performance
SetPrivateProfileString('Program Options','Maximum Frame Rate','60')

-- UX
SetPrivateProfileString('Program Options','Tooltips','0')      -- 0 = instant

-- Skip intro movie (mark as already-seen). PST:EE ships a single intro
-- named OPENING.wbm under lang/<locale>/movies/.
SetPrivateProfileString('Movies','OPENING','1')
