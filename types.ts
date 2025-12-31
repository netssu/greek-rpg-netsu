export type AttributeKey = 'dynamis' | 'aegis' | 'nous' | 'thymos';
export type SkillKey = 'combate' | 'atletismo' | 'astucia' | 'erudicao' | 'presenca' | 'sobrevivencia';
export type ArmorWeight = 'none' | 'light' | 'medium' | 'heavy';
export type ShieldWeight = 'none' | 'light' | 'heavy';

export interface Attributes {
  dynamis: number; // Força
  aegis: number;   // Destreza
  nous: number;    // Mente
  thymos: number;  // Ânimo/Vontade
}

export interface Skills {
  combate: number;
  atletismo: number;
  astucia: number;
  erudicao: number;
  presenca: number;
  sobrevivencia: number;
}

export interface Power {
  id: string;
  name: string;
  type: 'Traço' | 'Dádiva' | 'Dom';
  description: string;
  cost: string; // e.g. "2 SP" or "1 FD"
}

export interface Item {
  id: string;
  name: string;
  description: string;
  quantity: number;
}

export interface EquippedWeapon {
  name: string;
  type: 'meele_str' | 'meele_dex' | 'ranged';
  damage: string; // ex: "3d6 + For + 1"
  rules: string;
}

export interface Character {
  name: string;
  patron: string; // God
  level: number;
  xp: number;
  
  // Stats
  attributes: Attributes;
  skills: Skills;
  
  // Resources (Current values)
  currentHp: number;
  currentSp: number;
  currentFd: number;
  
  // Equipment stats
  armorWeight: ArmorWeight;
  armorBonus: number; // Magic/Extra bonus to RD
  
  shieldWeight: ShieldWeight;
  shieldBonus: number; // Magic/Extra bonus to Block
  
  weaponBonus: number; // Bonus to Attack
  equippedWeapon: EquippedWeapon;

  powers: Power[];
  inventory: Item[];
  notes: string;
  gold: number;
  
  activeConditions: string[]; // Array of condition names
  conditionNotes: string; // Free text
}

export const GODS = [
  "Zeus", "Hera", "Poseidon", "Deméter", "Atena", 
  "Apolo", "Ártemis", "Ares", "Afrodite", "Hefesto", 
  "Hermes", "Héstia", "Dionísio", "Hades", "Hércules"
];