import React, { useState, useRef } from 'react';
import { 
  Download, Upload, Shield, Heart, Zap, Swords, Star, 
  Plus, Trash2, Coins, Scroll, AlertTriangle, Edit3, Check, Menu, Scale
} from 'lucide-react';
import { Character, Attributes, Skills, GODS, ArmorWeight, ShieldWeight, SkillKey, EquippedWeapon } from './types';

// --- INITIAL STATE ---
const INITIAL_CHARACTER: Character = {
  name: "Herdeiro",
  patron: "",
  level: 1,
  xp: 0,
  attributes: { dynamis: 0, aegis: 0, nous: 0, thymos: 0 },
  skills: { combate: 0, atletismo: 0, astucia: 0, erudicao: 0, presenca: 0, sobrevivencia: 0 },
  currentHp: 10,
  currentSp: 4,
  currentFd: 2,
  armorWeight: 'none',
  armorBonus: 0,
  shieldWeight: 'none',
  shieldBonus: 0,
  weaponBonus: 0,
  equippedWeapon: { name: "Desarmado", type: 'meele_str', damage: "1", rules: "Corpo a corpo" },
  powers: [],
  inventory: [],
  notes: "",
  gold: 0,
  activeConditions: [],
  conditionNotes: ""
};

// --- DATA LISTS ---
const ARMOR_STATS: Record<ArmorWeight, { label: string, rd: number, spPenalty: number }> = {
  none:   { label: "Sem Armadura", rd: 0, spPenalty: 0 },
  light:  { label: "Leve", rd: 1, spPenalty: 0 },
  medium: { label: "Média", rd: 2, spPenalty: 1 },
  heavy:  { label: "Pesada", rd: 3, spPenalty: 2 },
};

const SHIELD_STATS: Record<ShieldWeight, { label: string, blockBonus: number, desc: string }> = {
  none:  { label: "Nenhum", blockBonus: 0, desc: "" },
  light: { label: "Leve (+1)", blockBonus: 1, desc: "+1 Bloq" },
  heavy: { label: "Pesado (+2)", blockBonus: 2, desc: "+2 Bloq" },
};

const CONDITIONS_LIST = [
  "Vulnerável", "Ofuscado", "Assustado", "Confuso", "Atordoado", 
  "Imobilizado", "Derrubado", "Desarmado", "Inconsciente", 
  "Sangrando", "Queimando", "Exausto", "Paralisado"
];

const WEAPON_PRESETS: Record<string, EquippedWeapon> = {
  "custom": { name: "Personalizada", type: 'meele_str', damage: "?", rules: "" },
  "desarmado": { name: "Desarmado", type: 'meele_str', damage: "1", rules: "Corpo a corpo" },
  "adaga": { name: "Adaga", type: 'meele_dex', damage: "2", rules: "Leve, Arremesso" },
  "espada": { name: "Espada/Lança", type: 'meele_str', damage: "3", rules: "Padrão" },
  "pesada": { name: "Machado/Martelo", type: 'meele_str', damage: "4", rules: "Pesada (Custa + SP)" },
  "arco": { name: "Arco Curto", type: 'ranged', damage: "3", rules: "Distância, Duas Mãos" },
};

type ResourceType = 'HP' | 'SP' | 'FD';

interface GodProfile {
  favored: ResourceType;
  lineageSkill: SkillKey;
}

const GOD_PROFILES: Record<string, GodProfile> = {
  "Zeus":     { favored: 'FD', lineageSkill: 'presenca' },
  "Hera":     { favored: 'HP', lineageSkill: 'presenca' },
  "Poseidon": { favored: 'SP', lineageSkill: 'atletismo' },
  "Deméter":  { favored: 'HP', lineageSkill: 'sobrevivencia' },
  "Atena":    { favored: 'SP', lineageSkill: 'erudicao' },
  "Apolo":    { favored: 'FD', lineageSkill: 'presenca' },
  "Ártemis":  { favored: 'SP', lineageSkill: 'sobrevivencia' },
  "Ares":     { favored: 'SP', lineageSkill: 'combate' },
  "Afrodite": { favored: 'FD', lineageSkill: 'presenca' },
  "Hefesto":  { favored: 'HP', lineageSkill: 'erudicao' },
  "Hermes":   { favored: 'SP', lineageSkill: 'astucia' },
  "Héstia":   { favored: 'HP', lineageSkill: 'presenca' },
  "Dionísio": { favored: 'FD', lineageSkill: 'astucia' },
  "Hades":    { favored: 'FD', lineageSkill: 'erudicao' },
  "Hércules": { favored: 'HP', lineageSkill: 'atletismo' }
};

export default function App() {
  const [char, setChar] = useState<Character>(INITIAL_CHARACTER);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // --- CALCULATIONS ---
  const calculateStats = () => {
    const profile = GOD_PROFILES[char.patron];
    const favoredBonus = Math.max(1, Math.floor(char.level / 2));
    
    // Base Values
    const hpBase = 10 + (profile?.favored === 'HP' ? favoredBonus : 0);
    const maxHp = hpBase + (2 * char.attributes.thymos) + char.attributes.dynamis + (char.level - 1);

    const spBase = 4 + (profile?.favored === 'SP' ? favoredBonus : 0);
    const armorPenalty = ARMOR_STATS[char.armorWeight].spPenalty;
    const maxSp = Math.max(0, spBase + char.attributes.dynamis + char.attributes.thymos - armorPenalty);

    const fdBaseNum = 2 + (profile?.favored === 'FD' ? favoredBonus : 0);
    const maxFd = Math.max(2, fdBaseNum + char.attributes.thymos);

    const initiative = char.attributes.aegis + char.attributes.nous;

    // Skills & Defenses (Roll Bonuses)
    const skillBonus = (key: SkillKey) => (profile?.lineageSkill === key ? 1 : 0);
    const getSkillTotal = (key: SkillKey) => char.skills[key] + skillBonus(key);

    // NOVA REGRA: Defesas são rolagens (3d6 + Bônus)
    // Esquiva = Destreza + Atletismo
    const esquiva = char.attributes.aegis + getSkillTotal('atletismo');
    
    // Bloqueio = Força + Escudo (Item + Mágico)
    const bloqueio = char.attributes.dynamis + SHIELD_STATS[char.shieldWeight].blockBonus + char.shieldBonus;
    
    // Aparar = Destreza + Combate (Assumindo uso de arma)
    const aparar = char.attributes.aegis + getSkillTotal('combate');
    
    // RD continua passiva
    const rdTotal = ARMOR_STATS[char.armorWeight].rd + char.armorBonus;

    // Attack Roll Base (3d6 + Attr + Combat + Weapon Bonus)
    const atkForce = char.attributes.dynamis + getSkillTotal('combate') + char.weaponBonus;
    const atkDex = char.attributes.aegis + getSkillTotal('combate') + char.weaponBonus;

    return { maxHp, maxSp, maxFd, initiative, esquiva, bloqueio, aparar, rdTotal, atkForce, atkDex, profile, getSkillTotal };
  };

  const stats = calculateStats();

  // --- HANDLERS ---
  const handleImport = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (event) => {
      try {
        const json = JSON.parse(event.target?.result as string);
        if (!json.armorWeight) json.armorWeight = 'none';
        if (!json.shieldWeight) json.shieldWeight = 'none';
        if (!json.activeConditions) json.activeConditions = [];
        if (!json.equippedWeapon) json.equippedWeapon = INITIAL_CHARACTER.equippedWeapon;
        setChar({ ...INITIAL_CHARACTER, ...json });
      } catch (err) {
        alert("Erro ao importar ficha.");
      }
    };
    reader.readAsText(file);
    e.target.value = '';
  };

  const handleExport = () => {
    const dataStr = "data:text/json;charset=utf-8," + encodeURIComponent(JSON.stringify(char, null, 2));
    const downloadAnchorNode = document.createElement('a');
    downloadAnchorNode.setAttribute("href", dataStr);
    downloadAnchorNode.setAttribute("download", `${char.name.replace(/\s+/g, '_')}_Olimpo.json`);
    document.body.appendChild(downloadAnchorNode);
    downloadAnchorNode.click();
    downloadAnchorNode.remove();
  };

  const updateAttr = (key: keyof Attributes, val: number) => setChar(p => ({...p, attributes: {...p.attributes, [key]: val}}));
  const updateSkill = (key: keyof Skills, val: number) => setChar(p => ({...p, skills: {...p.skills, [key]: val}}));


  const toggleCondition = (cond: string) => {
    setChar(prev => {
      const active = prev.activeConditions.includes(cond)
        ? prev.activeConditions.filter(c => c !== cond)
        : [...prev.activeConditions, cond];
      return { ...prev, activeConditions: active };
    });
  };

  const setWeaponPreset = (key: string) => {
    if (key === 'custom') return; 
    setChar(prev => ({ ...prev, equippedWeapon: { ...WEAPON_PRESETS[key] } }));
  };

  // --- COMPONENTS ---

  const AttributeBox = ({ label, short, value, onChange, desc }: any) => (
    <div className="flex flex-col items-center mb-3 relative group w-full">
      <div className="w-full border border-stone-300 rounded-lg bg-white flex flex-row items-center justify-between px-3 py-2 shadow-sm">
        <div className="flex flex-col items-start">
           <span className="text-[10px] uppercase font-bold text-stone-400 tracking-widest">{short}</span>
           <span className="text-xs font-bold text-stone-600">{label}</span>
        </div>
        <input 
          type="number" 
          value={value}
          onChange={(e) => onChange(parseInt(e.target.value) || 0)}
          className="w-12 text-center text-3xl font-serif font-bold text-stone-900 bg-white border border-stone-200 rounded focus:border-red-500 outline-none"
        />
      </div>
    </div>
  );

  const SkillRow = ({ label, base, bonus, onChange }: { label: string, base: number, bonus: number, onChange: (v: number) => void }) => {
    const total = base + bonus;
    const isTrained = bonus > 0;
    
    return (
      <div className="flex items-center gap-2 text-sm border-b border-stone-100 py-1.5 hover:bg-stone-50 transition-colors">
        {/* Total Display */}
        <div className={`w-6 h-6 rounded-full border flex items-center justify-center text-xs font-bold ${isTrained ? 'bg-stone-800 text-white border-stone-800' : 'bg-white border-stone-300 text-stone-800'}`}>
          {total}
        </div>
        
        {/* Label */}
        <span className={`uppercase tracking-wide flex-1 ${isTrained ? 'text-stone-900 font-bold' : 'text-stone-500 font-medium'}`}>
          {label} {isTrained && <span className="text-[9px] text-stone-400 ml-1">(+1 Lin.)</span>}
        </span>

        {/* Controls */}
        <div className="flex items-center gap-1">
          <button 
             onClick={() => onChange(Math.max(0, base - 1))}
             className="w-5 h-5 flex items-center justify-center bg-stone-200 hover:bg-stone-300 rounded text-stone-600 font-bold leading-none pb-0.5"
             tabIndex={-1}
          >-</button>
          <span className="text-xs font-bold text-stone-400 w-3 text-center">{base}</span>
          <button 
             onClick={() => onChange(Math.min(3, base + 1))}
             className="w-5 h-5 flex items-center justify-center bg-stone-200 hover:bg-stone-300 rounded text-stone-600 font-bold leading-none pb-0.5"
             tabIndex={-1}
          >+</button>
        </div>
      </div>
    );
  };

  const VitalBox = ({ label, current, max, setVal, icon: Icon, favored }: any) => (
    <div className={`flex-1 border rounded-lg bg-white p-3 flex flex-col relative shadow-sm ${favored ? 'border-amber-400 ring-1 ring-amber-100' : 'border-stone-300'}`}>
      {favored && <div className="absolute top-0 right-0 bg-amber-400 text-white text-[9px] font-bold px-1.5 py-0.5 rounded-bl">FAV</div>}
      <div className="flex justify-between items-center mb-1">
        <span className="text-xs font-bold text-stone-400 uppercase tracking-widest">{label}</span>
        <span className="text-xs font-bold text-stone-400">MAX: {max}</span>
      </div>
      <div className="flex items-center gap-3">
        <Icon size={24} className={favored ? "text-amber-500" : "text-stone-300"} />
        <input 
          type="number" 
          value={current}
          onChange={(e) => setVal(parseInt(e.target.value) || 0)}
          className="w-full text-4xl font-serif font-bold text-center bg-white border-b border-stone-200 outline-none focus:border-red-500 text-stone-800"
        />
      </div>
    </div>
  );

  const DefenseRoll = ({ label, value, sub }: any) => (
    <div className="flex flex-col items-center">
      <div className="w-20 h-20 rounded-full border-2 border-stone-800 bg-white flex flex-col items-center justify-center shadow-sm relative overflow-hidden">
        <span className="text-[10px] uppercase font-bold text-stone-400 absolute top-2">3d6</span>
        <span className="text-3xl font-serif font-bold text-stone-900 leading-none mt-1">+{value}</span>
      </div>
      <span className="text-[10px] text-stone-500 font-bold uppercase mt-1">{label}</span>
      {sub && <span className="text-[9px] text-stone-400 font-bold">{sub}</span>}
    </div>
  );

  return (
    <div className="min-h-screen bg-[#f3f4f6] font-sans text-stone-800">
      
      {/* TOOLBAR (Header) */}
      <div className="bg-stone-900 text-stone-400 py-2 px-6 shadow-md print:hidden mb-4">
        <div className="max-w-6xl mx-auto flex justify-between items-center">
          <div className="flex items-center gap-2">
            <Shield size={18} className="text-amber-600"/>
            <span className="font-serif font-bold text-stone-200">Herdeiros do Olimpo</span>
          </div>
          <div className="flex gap-4">
            <button onClick={() => fileInputRef.current?.click()} className="flex items-center gap-2 hover:text-white transition-colors text-xs font-bold uppercase">
              <Upload size={16}/> Importar Ficha
            </button>
            <input type="file" ref={fileInputRef} className="hidden" accept=".json" onChange={handleImport} />
            <button onClick={handleExport} className="flex items-center gap-2 hover:text-white transition-colors text-xs font-bold uppercase">
              <Download size={16}/> Exportar JSON
            </button>
          </div>
        </div>
      </div>
      
      {/* SHEET CONTAINER */}
      <div className="max-w-6xl mx-auto bg-white shadow-xl rounded border border-stone-200 p-8 relative print:shadow-none print:border-none print:p-0 mb-12">
        
        {/* --- TITLE & IDENTITY --- */}
        <div className="border-b-4 border-double border-stone-200 pb-6 mb-8 flex flex-col md:flex-row items-end gap-6">
           <div className="flex-1">
              <h1 className="text-4xl font-serif font-bold text-stone-900 tracking-tight">HERDEIROS</h1>
              <div className="flex gap-2 items-center text-red-800 font-bold uppercase tracking-widest text-xs">
                 <span>Do Olimpo RPG</span>
                 <span className="h-px w-10 bg-red-800"></span>
                 <span>Ficha de Personagem</span>
              </div>
           </div>
           
           <div className="flex-1 w-full grid grid-cols-2 md:grid-cols-4 gap-4">
              <div className="col-span-2">
                 <label className="block text-[10px] font-bold text-stone-400 uppercase tracking-wider">Nome</label>
                 <input 
                   type="text" 
                   value={char.name} 
                   onChange={(e) => setChar({...char, name: e.target.value})}
                   className="w-full border-b border-stone-300 py-1 font-serif font-bold text-xl text-stone-900 focus:border-red-600 bg-white outline-none"
                 />
              </div>
              <div className="relative">
                 <label className="block text-[10px] font-bold text-stone-400 uppercase tracking-wider">Patrono</label>
                 <select 
                   value={char.patron} 
                   onChange={(e) => setChar({...char, patron: e.target.value})}
                   className="w-full border-b border-stone-300 py-1 font-bold text-stone-800 bg-white outline-none appearance-none cursor-pointer"
                 >
                    <option value="">Selecione...</option>
                    {GODS.map(g => <option key={g} value={g}>{g}</option>)}
                 </select>
              </div>
              <div>
                 <label className="block text-[10px] font-bold text-stone-400 uppercase tracking-wider">Nível / XP</label>
                 <div className="flex items-center gap-1">
                    <input type="number" value={char.level} onChange={(e) => setChar({...char, level: parseInt(e.target.value)||1})} className="w-1/2 border-b border-stone-300 py-1 font-bold text-center bg-white outline-none"/>
                    <span className="text-stone-300">/</span>
                    <input type="number" value={char.xp} onChange={(e) => setChar({...char, xp: parseInt(e.target.value)||0})} className="w-1/2 border-b border-stone-300 py-1 text-center text-sm text-stone-500 bg-white outline-none"/>
                 </div>
              </div>
           </div>
        </div>

        {/* --- VITALS BAR --- */}
        <div className="flex flex-col md:flex-row gap-4 mb-8 bg-stone-50 p-4 rounded-xl border border-stone-100">
           <VitalBox label="HP (Vida)" current={char.currentHp} max={stats.maxHp} setVal={(v:number)=>setChar({...char, currentHp:v})} icon={Heart} favored={stats.profile?.favored === 'HP'} />
           <VitalBox label="SP (Stamina)" current={char.currentSp} max={stats.maxSp} setVal={(v:number)=>setChar({...char, currentSp:v})} icon={Zap} favored={stats.profile?.favored === 'SP'} />
           <VitalBox label="FD (Favor)" current={char.currentFd} max={stats.maxFd} setVal={(v:number)=>setChar({...char, currentFd:v})} icon={Star} favored={stats.profile?.favored === 'FD'} />
        </div>

        {/* --- MAIN COLUMNS --- */}
        <div className="grid grid-cols-1 md:grid-cols-12 gap-8">
          
          {/* LEFT: ATTRIBUTES (3 cols) */}
          <div className="md:col-span-3 flex flex-col gap-6">
            <div>
              <h3 className="font-serif font-bold text-stone-900 border-b-2 border-stone-800 mb-4 pb-1">Atributos</h3>
              <AttributeBox label="Força" short="Dynamis" value={char.attributes.dynamis} onChange={(v:number) => updateAttr('dynamis', v)} />
              <AttributeBox label="Destreza" short="Aegis" value={char.attributes.aegis} onChange={(v:number) => updateAttr('aegis', v)} />
              <AttributeBox label="Mente" short="Nous" value={char.attributes.nous} onChange={(v:number) => updateAttr('nous', v)} />
              <AttributeBox label="Thymos" short="Thymos" value={char.attributes.thymos} onChange={(v:number) => updateAttr('thymos', v)} />
              
              <div className="mt-4 p-3 border border-stone-200 rounded bg-stone-50 text-center">
                 <span className="block text-[10px] font-bold text-stone-400 uppercase">Iniciativa</span>
                 <span className="text-2xl font-serif font-bold text-stone-800 leading-none">{stats.initiative}</span>
                 <span className="block text-[9px] text-stone-400 mt-1">3d6 + DES + MEN</span>
              </div>
            </div>

            <div>
              <h3 className="font-serif font-bold text-stone-900 border-b-2 border-stone-200 mb-2 pb-1">Perícias</h3>
              <SkillRow label="Combate" base={char.skills.combate} bonus={stats.profile?.lineageSkill === 'combate' ? 1 : 0} onChange={(v) => updateSkill('combate', v)} />
              <SkillRow label="Atletismo" base={char.skills.atletismo} bonus={stats.profile?.lineageSkill === 'atletismo' ? 1 : 0} onChange={(v) => updateSkill('atletismo', v)} />
              <SkillRow label="Astúcia" base={char.skills.astucia} bonus={stats.profile?.lineageSkill === 'astucia' ? 1 : 0} onChange={(v) => updateSkill('astucia', v)} />
              <SkillRow label="Erudição" base={char.skills.erudicao} bonus={stats.profile?.lineageSkill === 'erudicao' ? 1 : 0} onChange={(v) => updateSkill('erudicao', v)} />
              <SkillRow label="Presença" base={char.skills.presenca} bonus={stats.profile?.lineageSkill === 'presenca' ? 1 : 0} onChange={(v) => updateSkill('presenca', v)} />
              <SkillRow label="Sobrevivência" base={char.skills.sobrevivencia} bonus={stats.profile?.lineageSkill === 'sobrevivencia' ? 1 : 0} onChange={(v) => updateSkill('sobrevivencia', v)} />
            </div>
          </div>

          {/* MIDDLE: COMBAT (5 cols) */}
          <div className="md:col-span-5 flex flex-col gap-8">
            
            {/* Defenses */}
            <div className="bg-stone-50 rounded-lg p-6 border border-stone-200 relative">
               <h3 className="absolute -top-3 left-6 bg-stone-50 px-2 font-serif font-bold text-stone-900 uppercase text-sm border border-stone-200 rounded shadow-sm">
                 <span className="text-red-600 mr-1">●</span>Defesas (Reações)
               </h3>
               
               <div className="flex justify-around items-center mb-6">
                  {/* RD editável */}
                  <div className="flex flex-col items-center group relative">
                    <div className="w-14 h-14 rounded border-2 border-stone-300 bg-white flex items-center justify-center shadow-sm">
                      <input 
                        type="number"
                        value={stats.rdTotal}
                        onChange={(e) => {
                           const newTotal = parseInt(e.target.value) || 0;
                           const baseRd = ARMOR_STATS[char.armorWeight].rd;
                           setChar(prev => ({ ...prev, armorBonus: newTotal - baseRd }));
                        }}
                        className="w-full h-full text-center text-2xl font-serif font-bold text-stone-800 bg-transparent outline-none rounded"
                      />
                    </div>
                    <span className="text-[10px] text-stone-400 font-bold uppercase mt-1">RD (Total)</span>
                  </div>

                  <DefenseRoll label="Bloqueio" value={stats.bloqueio} sub="FOR + Escudo" />
                  <DefenseRoll label="Esquiva" value={stats.esquiva} sub="DES + Atletismo" />
               </div>
               
               <div className="grid grid-cols-2 gap-4 text-xs">
                  <div>
                    <label className="block font-bold text-stone-500 mb-1">Armadura</label>
                    <select 
                      value={char.armorWeight}
                      onChange={(e) => setChar({...char, armorWeight: e.target.value as ArmorWeight})}
                      className="w-full p-1.5 border border-stone-300 rounded bg-white font-bold text-stone-800"
                    >
                      {Object.entries(ARMOR_STATS).map(([k,v]) => <option key={k} value={k}>{v.label} (RD {v.rd})</option>)}
                    </select>
                    <div className="flex items-center justify-between mt-1 px-1">
                      <span className="text-stone-400">Bônus:</span>
                      <input type="number" className="w-10 text-center border-b border-stone-300 bg-white" value={char.armorBonus} onChange={e=>setChar({...char, armorBonus: parseInt(e.target.value)||0})}/>
                    </div>
                  </div>
                  <div>
                    <label className="block font-bold text-stone-500 mb-1">Escudo</label>
                    <select 
                      value={char.shieldWeight}
                      onChange={(e) => setChar({...char, shieldWeight: e.target.value as ShieldWeight})}
                      className="w-full p-1.5 border border-stone-300 rounded bg-white font-bold text-stone-800"
                    >
                      {Object.entries(SHIELD_STATS).map(([k,v]) => <option key={k} value={k}>{v.label}</option>)}
                    </select>
                     <div className="flex items-center justify-between mt-1 px-1">
                      <span className="text-stone-400">Bônus:</span>
                      <input type="number" className="w-10 text-center border-b border-stone-300 bg-white" value={char.shieldBonus} onChange={e=>setChar({...char, shieldBonus: parseInt(e.target.value)||0})}/>
                    </div>
                  </div>
               </div>
               
               <div className="mt-4 pt-3 border-t border-stone-200 text-center flex justify-center items-center gap-2">
                  <div className="flex flex-col items-center">
                     <span className="text-xl font-serif font-bold text-stone-800 bg-white px-2 rounded border border-stone-200">
                        3d6 + {stats.aparar}
                     </span>
                     <span className="text-[10px] font-bold text-stone-400 uppercase mt-1">Aparar (Arma)</span>
                  </div>
               </div>
            </div>

            {/* Weapon & Attack */}
            <div className="border-2 border-stone-800 rounded p-1">
               <div className="bg-stone-800 text-white p-2 flex justify-between items-center px-4">
                 <div className="flex flex-col">
                   <span className="font-serif font-bold uppercase tracking-wide">Ataque (Ação)</span>
                   <span className="text-[9px] text-stone-400 font-normal">Teste Oposto: Ataque vs Defesa</span>
                 </div>
               </div>
               
               <div className="p-4 bg-white">
                 {/* Weapon Selector */}
                 <div className="mb-4 flex gap-2">
                   <select 
                     onChange={(e) => setWeaponPreset(e.target.value)}
                     className="flex-1 p-2 border border-stone-300 rounded bg-white font-bold text-stone-800 text-sm"
                   >
                     <option value="custom">Equipar Arma...</option>
                     <option value="desarmado">Desarmado</option>
                     <option value="adaga">Adaga</option>
                     <option value="espada">Espada / Lança</option>
                     <option value="pesada">Machado / Martelo</option>
                     <option value="arco">Arco</option>
                   </select>
                   <div className="bg-stone-100 px-3 py-2 rounded border border-stone-200 font-bold text-stone-800 whitespace-nowrap flex flex-col items-end leading-tight">
                     <span className="text-sm">3d6 + {char.equippedWeapon.type === 'meele_dex' || char.equippedWeapon.type === 'ranged' ? stats.atkDex : stats.atkForce}</span>
                     <span className="text-[9px] text-stone-400 uppercase">Acerto</span>
                   </div>
                 </div>

                 {/* Custom Edit Fields */}
                 <div className="grid grid-cols-12 gap-2">
                    <div className="col-span-4">
                       <label className="text-[9px] font-bold text-stone-400 uppercase">Nome da Arma</label>
                       <input 
                         type="text" 
                         value={char.equippedWeapon.name} 
                         onChange={(e) => setChar({...char, equippedWeapon: {...char.equippedWeapon, name: e.target.value}})}
                         className="w-full border-b border-stone-300 bg-white font-serif font-bold text-stone-900 focus:border-red-500 outline-none"
                       />
                    </div>
                    <div className="col-span-3">
                       <label className="text-[9px] font-bold text-stone-400 uppercase">Dano Base</label>
                       <input 
                         type="text" 
                         value={char.equippedWeapon.damage} 
                         onChange={(e) => setChar({...char, equippedWeapon: {...char.equippedWeapon, damage: e.target.value}})}
                         className="w-full border-b border-stone-300 bg-white font-bold text-red-800 focus:border-red-500 outline-none"
                       />
                    </div>
                    <div className="col-span-5">
                       <label className="text-[9px] font-bold text-stone-400 uppercase">Regras / Tipo</label>
                       <input 
                         type="text" 
                         value={char.equippedWeapon.rules} 
                         onChange={(e) => setChar({...char, equippedWeapon: {...char.equippedWeapon, rules: e.target.value}})}
                         className="w-full border-b border-stone-300 bg-white text-xs text-stone-600 focus:border-red-500 outline-none"
                       />
                    </div>
                 </div>
                 
                 <div className="mt-2 bg-red-50 p-2 rounded border border-red-100 flex items-center gap-2">
                    <Scale size={16} className="text-red-400"/>
                    <span className="text-[10px] text-red-800 font-bold">
                       DANO TOTAL = {char.equippedWeapon.damage || "0"} + MARGEM DE SUCESSO
                    </span>
                 </div>
                 
                 <div className="mt-3 text-[10px] text-stone-400 flex gap-4">
                    <label className="flex items-center gap-1 cursor-pointer">
                      <input 
                        type="radio" name="wtype" 
                        checked={char.equippedWeapon.type === 'meele_str'} 
                        onChange={() => setChar({...char, equippedWeapon: {...char.equippedWeapon, type: 'meele_str'}})}
                      /> Força
                    </label>
                    <label className="flex items-center gap-1 cursor-pointer">
                      <input 
                        type="radio" name="wtype" 
                        checked={char.equippedWeapon.type === 'meele_dex'} 
                        onChange={() => setChar({...char, equippedWeapon: {...char.equippedWeapon, type: 'meele_dex'}})}
                      /> Destreza (Corpo)
                    </label>
                    <label className="flex items-center gap-1 cursor-pointer">
                      <input 
                        type="radio" name="wtype" 
                        checked={char.equippedWeapon.type === 'ranged'} 
                        onChange={() => setChar({...char, equippedWeapon: {...char.equippedWeapon, type: 'ranged'}})}
                      /> Destreza (Distância)
                    </label>
                 </div>
               </div>
            </div>

            {/* Conditions Checklist */}
            <div className="border border-stone-200 rounded p-4 bg-white shadow-sm">
               <h3 className="font-serif font-bold text-stone-900 mb-3 flex items-center gap-2 text-sm border-b pb-1">
                 <AlertTriangle size={14} className="text-red-600"/> Condições Ativas
               </h3>
               <div className="grid grid-cols-2 gap-y-2 gap-x-4 mb-3">
                 {CONDITIONS_LIST.map(cond => (
                   <label key={cond} className="flex items-center gap-2 cursor-pointer group select-none">
                     <div className={`w-4 h-4 rounded border flex items-center justify-center transition-colors ${char.activeConditions.includes(cond) ? 'bg-red-600 border-red-600' : 'bg-white border-stone-300 group-hover:border-red-400'}`}>
                       {char.activeConditions.includes(cond) && <Check size={12} className="text-white" />}
                     </div>
                     <span className={`text-xs ${char.activeConditions.includes(cond) ? 'font-bold text-red-700' : 'text-stone-600'}`}>{cond}</span>
                     <input type="checkbox" className="hidden" checked={char.activeConditions.includes(cond)} onChange={() => toggleCondition(cond)} />
                   </label>
                 ))}
               </div>
               <input 
                  type="text"
                  placeholder="Detalhes (Ex: Envenenado 2 turnos...)"
                  value={char.conditionNotes}
                  onChange={(e) => setChar({...char, conditionNotes: e.target.value})}
                  className="w-full text-xs border-b border-stone-300 py-1 bg-white outline-none focus:border-red-500 placeholder-stone-400"
               />
            </div>

          </div>

          {/* RIGHT: POWERS & INVENTORY (4 cols) */}
          <div className="md:col-span-4 flex flex-col gap-6 h-full max-h-[calc(100vh-200px)]">
             
             {/* Powers Section - SCROLLABLE */}
             <div className="flex-1 flex flex-col min-h-[400px] border border-stone-200 rounded-lg bg-stone-50 overflow-hidden">
                <div className="flex items-center justify-between border-b border-stone-200 p-3 bg-white">
                   <h3 className="font-serif font-bold text-stone-900">Poderes & Dons</h3>
                   <button 
                     onClick={() => setChar(p => ({...p, powers: [...p.powers, { id: Date.now().toString(), name: "Novo Poder", type: 'Dádiva', cost: "", description: "" }] }))}
                     className="text-xs bg-stone-800 text-white px-2 py-1 rounded hover:bg-stone-700 transition-colors flex items-center gap-1"
                   >
                     <Plus size={12}/> Adicionar
                   </button>
                </div>
                
                <div className="overflow-y-auto p-3 space-y-3 custom-scrollbar">
                   {char.powers.length === 0 && (
                     <div className="p-6 text-center text-stone-400 text-sm italic">
                       Nenhum poder registrado.
                     </div>
                   )}
                   
                   {char.powers.map((p, idx) => (
                      <div key={p.id} className="bg-white border border-stone-200 rounded shadow-sm hover:shadow-md transition-shadow relative p-3">
                         <div className="flex justify-between items-start mb-2">
                            <input 
                              className="font-serif font-bold text-stone-900 text-lg bg-transparent outline-none w-full placeholder-stone-300"
                              placeholder="Nome do Poder"
                              value={p.name}
                              onChange={(e) => {
                                 const arr = [...char.powers]; arr[idx].name = e.target.value; setChar({...char, powers: arr});
                              }}
                            />
                            <button onClick={() => setChar(prev => ({...prev, powers: prev.powers.filter(x => x.id !== p.id)}))} className="text-stone-300 hover:text-red-600 p-1"><Trash2 size={14}/></button>
                         </div>
                         
                         <div className="flex gap-2 mb-2 items-center">
                            <select 
                              value={p.type}
                              onChange={(e) => {
                                 const arr = [...char.powers]; arr[idx].type = e.target.value as any; setChar({...char, powers: arr});
                              }}
                              className="text-[10px] font-bold uppercase bg-stone-100 px-2 py-1 rounded text-stone-600 border-none outline-none cursor-pointer"
                            >
                               <option>Traço</option><option>Dádiva</option><option>Dom</option>
                            </select>
                            <input 
                              className="text-[10px] font-bold text-red-800 bg-transparent outline-none w-24 placeholder-stone-400 border-b border-stone-100"
                              placeholder="Custo (ex: 2 SP)"
                              value={p.cost}
                              onChange={(e) => {
                                 const arr = [...char.powers]; arr[idx].cost = e.target.value; setChar({...char, powers: arr});
                              }}
                            />
                         </div>
                         
                         <textarea 
                            className="w-full text-sm text-stone-700 bg-transparent outline-none resize-none h-auto min-h-[5rem] leading-relaxed border-t border-stone-100 pt-2"
                            value={p.description}
                            placeholder="Descrição completa do efeito..."
                            onChange={(e) => {
                                 const arr = [...char.powers]; arr[idx].description = e.target.value; setChar({...char, powers: arr});
                            }}
                         />
                      </div>
                   ))}
                </div>
             </div>

             {/* Inventory - Fixed Height */}
             <div className="border-t-2 border-stone-200 pt-4">
                <h3 className="font-serif font-bold text-stone-900 mb-2 text-sm flex items-center gap-2">
                  <Scroll size={14}/> Inventário
                </h3>
                <textarea 
                  className="w-full h-40 bg-white border border-stone-300 rounded p-2 text-sm text-stone-700 outline-none resize-none focus:border-stone-400 shadow-inner"
                  placeholder="Equipamentos, poções, itens de história..."
                  value={char.notes}
                  onChange={(e) => setChar({...char, notes: e.target.value})}
                />
                <div className="mt-2 flex items-center justify-end gap-2">
                   <Coins size={14} className="text-yellow-600"/>
                   <span className="text-xs font-bold text-stone-500 uppercase">Ouro:</span>
                   <input 
                     type="number" 
                     value={char.gold}
                     onChange={(e) => setChar({...char, gold: parseInt(e.target.value) || 0})}
                     className="w-20 border-b border-stone-300 text-right font-bold bg-white outline-none"
                   />
                </div>
             </div>

          </div>

        </div>
        
        {/* FOOTER */}
        <div className="text-center mt-12 pt-4 border-t border-stone-100">
           <p className="text-[10px] text-stone-400 font-bold uppercase tracking-widest">Herdeiros do Olimpo RPG • v29/12/2025</p>
        </div>

      </div>
    </div>
  );
}