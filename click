<script>
    /* ---------------------------------------------------------------------- */
    /* --- CONFIGURACIÓN DE JUEGO (RECURSOS Y DATOS LIMPIOS PARA GITHUB) --- */
    /* ---------------------------------------------------------------------- */

    // NOTA IMPORTANTE: Todos los archivos de imagen deben estar en una carpeta llamada 'images'
    // en el mismo nivel que tu archivo HTML.

    const GAME_ASSETS = {
        // Héroe (Reemplazando URLs de iBB por rutas locales)
        HERO_BOY: "./images/hero_boy.png",
        HERO_GIRL: "./images/hero_girl.png",

        // Fondos de Mapa (Reemplazando URLs de Google por rutas locales)
        MAP_BG: "./images/bg_map.png",
        WORLD_BGS: {
            1: "./images/bg_forest.png",   // Mapa 1: Bosque
            2: "./images/bg_cave.png",     // Mapa 2: Cueva de Cristal
            3: "./images/bg_volcano.png"   // Mapa 3: Volcán
        },

        // Monstruos (Reconstrucción de la data con rutas locales)
        MONSTERS: [
            // World 1: Bosque Mágico
            { name: "Slime", hp: 10, dmg: 2, xp: 5, gold: 3, img: "./images/monster_slime.png", world: 1 },
            { name: "Mushroom", hp: 15, dmg: 3, xp: 8, gold: 5, img: "./images/monster_mushroom.png", world: 1 },
            { name: "Goblin", hp: 25, dmg: 5, xp: 12, gold: 8, img: "./images/monster_goblin.png", world: 1 },
            { name: "Giant Bat", hp: 50, dmg: 10, xp: 50, gold: 20, img: "./images/monster_bat.png", world: 1, isBoss: true },

            // World 2: Cueva de Cristal
            { name: "Rock Golem", hp: 80, dmg: 15, xp: 20, gold: 12, img: "./images/monster_golem.png", world: 2 },
            { name: "Spider Queen", hp: 120, dmg: 20, xp: 30, gold: 18, img: "./images/monster_spider.png", world: 2 },
            { name: "Fire Imp", hp: 200, dmg: 35, xp: 150, gold: 40, img: "./images/monster_imp.png", world: 2, isBoss: true },

            // World 3: Volcán
            { name: "Fire Elemental", hp: 300, dmg: 45, xp: 60, gold: 30, img: "./images/monster_fire_elemental.png", world: 3 },
            { name: "Red Dragon", hp: 500, dmg: 70, xp: 100, gold: 50, img: "./images/monster_red_dragon.png", world: 3 },
            { name: "Lava Dragon King", hp: 1000, dmg: 120, xp: 500, gold: 100, img: "./images/monster_lava_dragon.png", world: 3, isBoss: true }
        ]
    };

    const HERO_BASE_STATS = {
        atk: 5, def: 1, m_atk: 3, m_def: 1, maxHp: 100, maxMp: 50, gold: 0, xp: 0, nextLvlXp: 100
    };

    const SKILLS = [
        { id: 'attack', name: 'Ataque Básico', icon: '🗡️', cost: 0, locked: false, isPhysical: true, damage: 1 },
        { id: 'fireball', name: 'Bola de Fuego', icon: '🔥', cost: 10, locked: false, isPhysical: false, damage: 2.5 },
        { id: 'heal', name: 'Curar', icon: '✨', cost: 15, locked: true, isPhysical: false, damage: -3 },
        { id: 'heavy', name: 'Golpe Pesado', icon: '🔨', cost: 20, locked: true, isPhysical: true, damage: 3.5 }
    ];

    let Game = {
        hero: {
            hp: 100, maxHp: 100, mp: 50, maxMp: 50, lvl: 1, xp: 0, nextLvlXp: 100,
            atk: HERO_BASE_STATS.atk, def: HERO_BASE_STATS.def, m_atk: HERO_BASE_STATS.m_atk, m_def: HERO_BASE_STATS.m_def,
            gold: HERO_BASE_STATS.gold, img: "",
            skills: SKILLS
        },
        currentWorld: 1,
        unlockedWorlds: 1,
        worldStage: 1,
        enemy: { active: false, hp: 0, maxHp: 0, data: null },
        loops: { target: null, attack: null }
    };

    /* --- SETUP --- */
    function selectHero(type) {
        // Usar rutas locales
        Game.hero.img = type === 'boy' ? GAME_ASSETS.HERO_BOY : GAME_ASSETS.HERO_GIRL;
        document.getElementById('hud-icon').src = Game.hero.img;
        document.getElementById('hero-img').src = Game.hero.img;
        document.getElementById('select-hint').classList.add('hidden');
        document.getElementById('start-btn').classList.remove('hidden');
    }

    /* --- NAVIGATION --- */
    function goToMap() {
        // Setea el fondo del mapa con la ruta local
        document.getElementById('map-container').style.backgroundImage = `url(${GAME_ASSETS.MAP_BG})`;
        document.getElementById('title-screen').classList.add('hidden');
        document.getElementById('map-screen').classList.remove('hidden');
        document.getElementById('combat-screen').classList.add('hidden');
        stopLoops();
        updateUI();
    }

    function goToCombat(world) {
        Game.currentWorld = world;
        Game.worldStage = 1; // Reinicia el stage
        // Setea el fondo de combate con la ruta local
        document.getElementById('combat-arena').style.backgroundImage = `url(${GAME_ASSETS.WORLD_BGS[world]})`;
        document.getElementById('map-screen').classList.add('hidden');
        document.getElementById('combat-screen').classList.remove('hidden');
        startCombat();
    }

    function backToMap() {
        document.getElementById('map-screen').classList.remove('hidden');
        document.getElementById('combat-screen').classList.add('hidden');
        stopLoops();
        Game.enemy.active = false;
        updateUI();
    }

    /* --- COMBAT LOGIC --- */
    function startCombat() {
        stopLoops();
        const availableMonsters = GAME_ASSETS.MONSTERS.filter(m => m.world === Game.currentWorld && !m.isBoss);
        if (availableMonsters.length === 0) {
            console.error("No hay monstruos disponibles para este mundo.");
            backToMap();
            return;
        }

        let monsterIndex;
        if (Game.worldStage % 5 === 0) {
            // Boss every 5 stages
            const boss = GAME_ASSETS.MONSTERS.find(m => m.world === Game.currentWorld && m.isBoss);
            if (boss) monsterIndex = GAME_ASSETS.MONSTERS.indexOf(boss);
        } else {
            // Random monster
            const randIndex = Math.floor(Math.random() * availableMonsters.length);
            monsterIndex = GAME_ASSETS.MONSTERS.indexOf(availableMonsters[randIndex]);
        }

        const enemyData = GAME_ASSETS.MONSTERS[monsterIndex];
        Game.enemy.data = { ...enemyData }; // Clonar data
        Game.enemy.hp = enemyData.hp;
        Game.enemy.maxHp = enemyData.hp;
        Game.enemy.active = true;

        // Actualizar UI del enemigo
        document.getElementById('enemy-img').src = Game.enemy.data.img;
        document.getElementById('enemy-name').textContent = Game.enemy.data.name;
        document.getElementById('world-stage-title').textContent = `MUNDO ${Game.currentWorld} - STAGE ${Game.worldStage}`;
        document.getElementById('combat-message').textContent = `¡Un ${Game.enemy.data.name} salvaje aparece!`;

        updateUI();

        // Iniciar el loop de ataque del enemigo y el loop de target
        Game.loops.attack = setInterval(enemyAttack, 3000);
        Game.loops.target = setInterval(spawnTarget, 2000);
    }

    function spawnTarget() {
        const t = document.createElement('div');
        t.className = 'target-spot pointer-events-auto';
        t.style.left = (Math.random() * 60 + 20) + '%';
        t.style.top = (Math.random() * 50 + 20) + '%';
        t.onmousedown = (e) => {
            e.stopPropagation();
            t.remove();
            heroAttack(false); // Ataque básico al target
        };
        document.getElementById('target-layer').appendChild(t);
        setTimeout(() => {
            if (t.parentNode) t.remove();
        }, 1500);
    }

    function heroAttack(isSkill = false, skillId = 'attack') {
        if (!Game.enemy.active) return;

        let dmg = 0;
        let skill = Game.hero.skills.find(s => s.id === skillId);

        if (isSkill) {
            if (Game.hero.mp < skill.cost) {
                document.getElementById('combat-message').textContent = "¡MP insuficiente!";
                return;
            }
            Game.hero.mp = Math.max(0, Game.hero.mp - skill.cost);
        }

        if (skill.damage < 0) { // Heal
            let healAmount = Game.hero.m_atk * Math.abs(skill.damage);
            Game.hero.hp = Math.min(Game.hero.maxHp, Game.hero.hp + healAmount);
            showComicText(`+${Math.round(healAmount)} HP`, 'hero-img', 'text-green-500');
            document.getElementById('combat-message').textContent = `${skill.name} realizado.`;
        } else { // Damage
            if (skill.isPhysical) {
                dmg = Math.max(1, Game.hero.atk * skill.damage - Game.enemy.data.def);
            } else {
                dmg = Math.max(1, Game.hero.m_atk * skill.damage - Game.enemy.data.m_def);
            }

            Game.enemy.hp = Math.max(0, Game.enemy.hp - dmg);

            const hc = document.getElementById('hero-img');
            hc.classList.remove('anim-bounce');
            hc.classList.add('anim-hero-attack');
            setTimeout(() => {
                hc.classList.remove('anim-hero-attack');
                hc.classList.add('anim-bounce');
            }, 300);

            showComicText(Math.round(dmg), 'enemy-container', 'text-red-500');
            document.getElementById('combat-message').textContent = `${skill.name} causó ${Math.round(dmg)} daño.`;
        }

        if (Game.enemy.hp <= 0) {
            enemyDefeated();
        }

        updateUI();
    }

    function enemyAttack() {
        if (!Game.enemy.active) return;
        const dmg = Math.max(1, Game.enemy.data.dmg - Game.hero.def);
        Game.hero.hp = Math.max(0, Game.hero.hp - dmg);

        const ec = document.getElementById('enemy-container');
        ec.classList.remove('anim-bounce');
        ec.classList.add('anim-monster-attack');
        setTimeout(() => {
            ec.classList.remove('anim-monster-attack');
            ec.classList.add('anim-bounce');
        }, 300);

        showComicText(Math.round(dmg), 'hero-img', 'text-yellow-500');
        document.getElementById('combat-message').textContent = `¡${Game.enemy.data.name} te ataca y hace ${Math.round(dmg)} daño!`;

        if (Game.hero.hp <= 0) {
            heroDefeated();
        }

        updateUI();
    }

    function enemyDefeated() {
        stopLoops();
        Game.enemy.active = false;

        // Recompensas
        Game.hero.gold += Game.enemy.data.gold;
        Game.hero.xp += Game.enemy.data.xp;

        // Mensaje
        document.getElementById('combat-message').textContent = `¡${Game.enemy.data.name} derrotado! Ganas ${Game.enemy.data.xp} XP y ${Game.enemy.data.gold} Oro.`;

        // Next Stage / Check World Complete
        if (Game.enemy.data.isBoss) {
            document.getElementById('boss-defeat-modal').classList.remove('hidden');
            document.getElementById('boss-name').textContent = Game.enemy.data.name;
            if (Game.currentWorld < 3) { // Asume 3 mundos
                document.getElementById('next-world-btn').classList.remove('hidden');
                document.getElementById('next-world-btn').textContent = `Ir a Mundo ${Game.currentWorld + 1}`;
                Game.unlockedWorlds = Math.max(Game.unlockedWorlds, Game.currentWorld + 1);
            } else {
                document.getElementById('next-world-btn').classList.add('hidden');
            }
        } else {
            Game.worldStage++;
            // Espera para el próximo combate
            setTimeout(startCombat, 2000);
        }

        // Check Level Up
        checkLevelUp();
        updateUI();
    }

    function checkLevelUp() {
        while (Game.hero.xp >= Game.hero.nextLvlXp) {
            Game.hero.lvl++;
            Game.hero.xp -= Game.hero.nextLvlXp;
            Game.hero.nextLvlXp = Math.round(Game.hero.nextLvlXp * 1.5);

            // Aumentar stats
            Game.hero.atk += 2;
            Game.hero.def += 1;
            Game.hero.m_atk += 2;
            Game.hero.m_def += 1;
            Game.hero.maxHp += 20;
            Game.hero.maxMp += 10;
            Game.hero.hp = Game.hero.maxHp;
            Game.hero.mp = Game.hero.maxMp;

            // Desbloquear habilidades (ejemplo: si llega a nivel 3, desbloquea Curar)
            let unlockedSkill = null;
            if (Game.hero.lvl === 3 && Game.hero.skills[2].locked) {
                Game.hero.skills[2].locked = false;
                unlockedSkill = Game.hero.skills[2];
            } else if (Game.hero.lvl === 5 && Game.hero.skills[3].locked) {
                Game.hero.skills[3].locked = false;
                unlockedSkill = Game.hero.skills[3];
            }

            // Mostrar modal de Level Up
            document.getElementById('levelup-modal').classList.remove('hidden');
            document.getElementById('levelup-msg').textContent = `¡Alcanzaste Nivel ${Game.hero.lvl}!`;
            document.getElementById('unlock-notification').classList.add('hidden');

            if (unlockedSkill) {
                document.getElementById('unlock-notification').classList.remove('hidden');
                document.getElementById('unlock-name').textContent = unlockedSkill.name.toUpperCase();
            }
        }
    }

    function closeLevelUpModal() {
        document.getElementById('levelup-modal').classList.add('hidden');
    }

    function closeBossDefeatModal() {
        document.getElementById('boss-defeat-modal').classList.add('hidden');
        backToMap();
    }

    function heroDefeated() {
        stopLoops();
        Game.enemy.active = false;
        document.getElementById('combat-message').textContent = "¡Has sido derrotado! Vuelves al mapa.";
        setTimeout(backToMap, 3000);
    }

    function useSkill(id, cost) {
        if (id === 'attack') {
            heroAttack(false);
        } else {
            heroAttack(true, id);
        }
    }

    /* --- UI UPDATES --- */
    function updateUI() {
        // HUD
        document.getElementById('hero-lvl').textContent = Game.hero.lvl;
        document.getElementById('hero-gold').textContent = Game.hero.gold;
        document.getElementById('hero-xp-bar').style.width = `${(Game.hero.xp / Game.hero.nextLvlXp) * 100}%`;

        // Hero Stats
        document.getElementById('hero-hp-bar').style.width = `${(Game.hero.hp / Game.hero.maxHp) * 100}%`;
        document.getElementById('hero-mp-bar').style.width = `${(Game.hero.mp / Game.hero.maxMp) * 100}%`;
        document.getElementById('hp-val').textContent = `${Math.round(Game.hero.hp)}/${Game.hero.maxHp} HP`;
        document.getElementById('mp-val').textContent = `${Math.round(Game.hero.mp)}/${Game.hero.maxMp} MP`;

        // Enemy Stats
        if (Game.enemy.active) {
            document.getElementById('enemy-hp-bar').style.width = `${(Game.enemy.hp / Game.enemy.maxHp) * 100}%`;
            document.getElementById('enemy-hp-val').textContent = `${Math.round(Game.enemy.hp)}/${Game.enemy.maxHp} HP`;
            document.getElementById('enemy-container').classList.remove('hidden');
        } else {
            document.getElementById('enemy-container').classList.add('hidden');
        }

        // Skills Menu
        const skillsMenu = document.getElementById('skills-menu');
        skillsMenu.innerHTML = '';
        Game.hero.skills.forEach(skill => {
            const item = document.createElement('div');
            const locked = skill.locked || Game.hero.mp < skill.cost; // Bloquea si no tiene MP suficiente
            item.className = `p-2 rounded-xl border-2 border-[#d6d3d1] flex items-center gap-3 group ${locked ? 'locked-skill' : 'hover:bg-[#fed7aa]'}`;
            if (!locked) item.onclick = () => useSkill(skill.id, skill.cost);
            item.innerHTML = `
                <div class="w-10 h-10 bg-gray-200 rounded border-2 border-gray-400 flex items-center justify-center text-xl shadow-sm">
                    ${skill.icon}
                </div>
                <div class="flex-1">
                    <span class="font-bold text-gray-800 block">${skill.name}</span>
                    <span class="text-sm text-gray-600">${skill.cost > 0 ? skill.cost + ' MP' : 'Gratis'}</span>
                </div>
                ${locked ? '<span class="material-symbols-outlined text-red-500">lock</span>' : ''}
            `;
            skillsMenu.appendChild(item);
        });

        // Map Buttons
        const worldButtons = document.querySelectorAll('[data-world]');
        worldButtons.forEach(button => {
            const world = parseInt(button.dataset.world);
            if (world > Game.unlockedWorlds) {
                button.classList.add('locked-world');
            } else {
                button.classList.remove('locked-world');
                button.onclick = () => goToCombat(world);
            }
        });
    }

    function stopLoops() {
        clearInterval(Game.loops.target);
        clearInterval(Game.loops.attack);
    }

    // UTILS
    function showComicText(text, targetId, colorClass) {
        const target = document.getElementById(targetId);
        const rect = target.getBoundingClientRect();
        const centerX = rect.left + rect.width / 2;
        const centerY = rect.top + rect.height / 2;

        const el = document.createElement('div');
        el.className = `comic-text ${colorClass}`;
        el.textContent = text;
        el.style.left = `${centerX}px`;
        el.style.top = `${centerY}px`;

        document.body.appendChild(el);

        setTimeout(() => {
            el.remove();
        }, 1000);
    }

    // Botón de descarga: Innecesario para GitHub Pages, pero se mantiene limpio.
    function downloadGame() {
        const htmlContent = document.documentElement.outerHTML;
        const blob = new Blob([htmlContent], { type: 'text/html' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'Toon_Legends_RPG.html';
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
</script>
