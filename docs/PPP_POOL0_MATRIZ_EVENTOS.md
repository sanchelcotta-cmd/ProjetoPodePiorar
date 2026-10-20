# Pool 0 — matriz auditável de Eventos e Informações

Leitura dos Resources pelo Godot 4.6.2 em 19/10/2026. **Esta é uma auditoria de dados e rotas, não a implementação dos modos.** Fonte reproduzível: `scripts/tests/ppp_pool0_resource_audit.gd`. O plano de integração está em `PPP_PROXIMA_LEVA_CAMPANHA_0_5.md`.

## Escopo e critérios

- 85 `EventData` carregados: 54 aleatórios de sorteio normal, 16 permanentes, 5 catástrofes, 5 armadilhas e 5 Eventos gerados pelo 09; os outros 5 `.tres` da pasta `gnomes_3` são animações, não Eventos. São 80 Eventos nos catálogos normais.
- 20 Informações e 36 Encontros carregados; todos os Encontros têm composição válida. Não há IDs vazios/duplicados de Evento, Informação ou Encontro, nem efeitos `TRIGGER_EVENT`/`GRANT_INFORMATION` com ID fixo órfão. `ev_00020` referencia 21–23 existentes; `ev_00009` referencia os cinco `gn_00001`–`gn_00005`; `ev_00002` referencia `in_00019` existente.
- **Direta específica** significa que um `EventConditionData.HAS_INFORMATION` consulta, no executor, uma tag de uma Informação obtida. Só 01–04 cumprem esse critério. Uma tag temática no Evento, uma fala ou o nome de inimigo não bastam.
- **Indireta genérica** significa que o outcome concede/sorteia ou esquece Informação sem exigir um desfecho específico: 17, 44 e o desejo `random_information` do 49. O 02 é direto **e** concede a Informação fixa `in_00019`.
- `pN` nas células de outcome é o **peso do outcome**; a coluna Peso é o **peso de seleção do Evento**. Cada outcome agora aparece com seu ID estável do Resource. “Todos¹” é elegibilidade por modo, sujeita às regras já existentes de categoria, valência, standby, frequência e condição própria. O filtro de tags está ligado ao modo selecionado na tela inicial e guardado em `CampaignState.campaign_mode`; Completa é o padrão.

## Matriz por Resource/ID

| Evento / Resource | Categoria / valência | Peso | Desfecho específico | Dependência | Condição mecânica | Outcomes e efeitos cadastrados | Informação concedida/removida | Modo planejado |
| --- | --- | ---: | --- | --- | --- | --- | --- | --- |
| [ev_00071](../resources/events/catastrophes/71-uma_praga_de_lavas.tres) | Catástrofe / Ruim | 1 | — | — | — | ev_00071_out_01[p1]: APPLY_ITEM_STATE | — | Todos¹ (dia > 1) |
| [ev_00072](../resources/events/catastrophes/72-nevasca.tres) | Catástrofe / Ruim | 1 | — | — | — | ev_00072_out_01[p1]: SET_MOVEMENT_LIMIT+MODIFY_STAT+MODIFY_STAT | — | Todos¹ (dia > 1) |
| [ev_00073](../resources/events/catastrophes/73-chuva_de_gafanhotos.tres) | Catástrofe / Ruim | 1 | — | — | — | ev_00073_out_01[p1]: MODIFY_HP+SUPPRESS_SKILLS | — | Todos¹ (dia > 1) |
| [ev_00074](../resources/events/catastrophes/74-portais_infernais.tres) | Catástrofe / Ruim | 1 | — | — | — | ev_00074_out_01[p1]: MODIFY_HP | — | Todos¹ (dia > 1) |
| [ev_00075](../resources/events/catastrophes/75-aurea_funebre.tres) | Catástrofe / Ruim | 1 | — | — | — | ev_00075_out_01[p1]: APPLY_STATUS | — | Todos¹ (dia > 1) |
| [ev_00055](../resources/events/permanent_effects/55-olhos_bionicos.tres) | Permanente / Boa | 1 | — | — | — | ev_00055_out_01[p1]: GRANT_ACTIVE_SKILL+GRANT_PASSIVE | — | Todos¹ |
| [ev_00056](../resources/events/permanent_effects/56-protese_do_terceiro_braco.tres) | Permanente / Boa | 1 | — | — | — | ev_00056_out_01[p1]: APPLY_SKILL_EFFECT+GRANT_PASSIVE | — | Todos¹ |
| [ev_00057](../resources/events/permanent_effects/57-gene_da_furia_bestial.tres) | Permanente / Boa | 1 | — | — | — | ev_00057_out_01[p1]: MODIFY_MAX_HP+GRANT_PASSIVE | — | Todos¹ |
| [ev_00058](../resources/events/permanent_effects/58-simbiose_elemental.tres) | Permanente / Boa | 1 | — | — | — | ev_00058_out_01[p1]: GRANT_PASSIVE | — | Todos¹ |
| [ev_00059](../resources/events/permanent_effects/59-pele_endurecida.tres) | Permanente / Boa | 1 | — | — | — | ev_00059_out_01[p1]: GRANT_STATUS_IMMUNITY+IGNORE_RANGED_CRITICAL_BONUS+GRANT_PASSIVE | — | Todos¹ |
| [ev_00060](../resources/events/permanent_effects/60-aurea_milagrosa.tres) | Permanente / Boa | 1 | — | — | — | ev_00060_out_01[p1]: GRANT_STATUS_IMMUNITY+GRANT_PASSIVE | — | Todos¹ |
| [ev_00061](../resources/events/permanent_effects/61-mutacao_genetica.tres) | Permanente / Boa | 1 | — | — | Encontro concluído | ev_00061_out_01[p1]: GRANT_PASSIVE | — | Todos¹ |
| [ev_00062](../resources/events/permanent_effects/62-informacao_e_poder.tres) | Permanente / Boa | 1 | — | — | — | ev_00062_out_01[p1]: GRANT_PASSIVE | — | Todos¹ |
| [ev_00063](../resources/events/permanent_effects/63-doguinho_caramelo.tres) | Permanente / Boa | 1 | — | — | — | ev_00063_out_01[p1]: ADD_COMPANION | — | Todos¹ |
| [ev_00064](../resources/events/permanent_effects/64-gatinho_vira_lata.tres) | Permanente / Boa | 1 | — | — | — | ev_00064_out_01[p1]: ADD_COMPANION | — | Todos¹ |
| [ev_00065](../resources/events/permanent_effects/65-um_aliado.tres) | Permanente / Boa | 1 | — | — | — | ev_00065_out_01[p1]: ADD_COMPANION | — | Todos¹ |
| [ev_00066](../resources/events/permanent_effects/66-voce_esta_doente.tres) | Permanente / Ruim | 1 | — | — | — | ev_00066_out_01[p1]: APPLY_STATUS | — | Todos¹ |
| [ev_00067](../resources/events/permanent_effects/67-todos_estao_doentes.tres) | Permanente / Ruim | 1 | — | — | — | ev_00067_out_01[p1]: APPLY_STATUS | — | Todos¹ |
| [ev_00068](../resources/events/permanent_effects/68-adestramento_bestial.tres) | Permanente / Ambígua | 1 | — | — | — | ev_00068_out_01[p1]: GRANT_ACTIVE_SKILL | — | Todos¹ |
| [ev_00069](../resources/events/permanent_effects/69-uma_maleta_de_cura.tres) | Permanente / Boa | 1 | — | — | — | ev_00069_out_01[p1]: GRANT_ACTIVE_SKILL | — | Todos¹ |
| [ev_00070](../resources/events/permanent_effects/70-arqui_inimigo.tres) | Permanente / Ambígua | 1 | — | — | — | ev_00070_out_01[p1]: GRANT_ACTIVE_SKILL | — | Todos¹ |
| [ev_00001](../resources/events/random_events/01-artefato_do_vazio.tres) | Aleatório / Ambígua | 1 | Khainokata | Direta | ev_00001_out_01: não tem Info Khainokata<br>ev_00001_out_02: tem Info Khainokata | ev_00001_out_01[p1]: MODIFY_MAX_HP<br>ev_00001_out_02[p1]: sem efeito cadastrado | — | Completa |
| [ev_00002](../resources/events/random_events/02-cobaia_secreta.tres) | Aleatório / Ambígua | 1 | Orchestra | Direta | ev_00002_out_01: não tem Info Orchestra<br>ev_00002_out_02: tem Info Orchestra | ev_00002_out_01[p1]: GRANT_INFORMATION(in_00019)+APPLY_STATUS+APPLY_STATUS<br>ev_00002_out_02[p1]: sem efeito cadastrado | in_00019 | Completa |
| [ev_00003](../resources/events/random_events/03-o_velho_louco.tres) | Aleatório / Ambígua | 2 | Homens de Preto | Direta | ev_00003_out_01: não tem Info Homens de Preto<br>regra: start_crazy_old_man_combat_scaled_to_group | ev_00003_out_01[p1]: CUSTOM<br>ev_00003_out_02[p1]: sem efeito cadastrado | — | Completa |
| [ev_00004](../resources/events/random_events/04-termos_de_uso.tres) | Aleatório / Ambígua | 2 | Controle da Mente | Direta | ev_00004_out_01: não tem Info Controle da Mente<br>regra: start_dancing_zombie_horde_by_district | ev_00004_out_01[p1]: CUSTOM<br>ev_00004_out_02[p1]: sem efeito cadastrado | — | Completa |
| [ev_00005](../resources/events/random_events/05-um_raio_te_atingiu_na_cabeça_1.tres) | Aleatório / Boa | 4 | — | — | — | ev_00005_out_01[p30]: MODIFY_HP+MODIFY_STAT<br>ev_00005_out_02[p30]: GRANT_PASSIVE+APPLY_SKILL_EFFECT<br>ev_00005_out_03[p30]: GRANT_PASSIVE+GRANT_PASSIVE<br>ev_00005_out_04[p10]: MODIFY_HP+MODIFY_STAT+GRANT_PASSIVE+GRANT_PASSIVE+GRANT_PASSIVE+APPLY_SKILL_EFFECT | — | Todos¹ |
| [ev_00006](../resources/events/random_events/06-um_raio_te_atingiu_na_cabeça_2.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00006_out_01[p1]: MODIFY_HP+APPLY_STATUS | — | Todos¹ |
| [ev_00007](../resources/events/random_events/07-gnomos_do_caos_1.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00007_out_01[p1]: TRANSFORM_INVENTORY | — | Todos¹ |
| [ev_00008](../resources/events/random_events/08-gnomos_do_caos_2.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00008_out_01[p1]: MASK_BLOCK_VISUALS | — | Todos¹ |
| [ev_00009](../resources/events/random_events/09-gnomos_do_caos_3.tres) | Aleatório / Ambígua | 1 | — | — | regra: spawn_gnomes_3<br>gera gn_00001, gn_00002, gn_00003, gn_00004, gn_00005 | ev_00009_out_01[p1]: CUSTOM | — | Todos¹ |
| [ev_00010](../resources/events/random_events/10-soro_desconhecido.tres) | Aleatório / Ambígua | 5 | — | — | — | ev_00010_out_01[p10]: MODIFY_MAX_HP+MODIFY_STAT<br>ev_00010_out_02[p20]: MODIFY_MAX_HP+MODIFY_STAT<br>ev_00010_out_03[p20]: GRANT_STATUS_IMMUNITY<br>ev_00010_out_04[p30]: APPLY_STATUS<br>ev_00010_out_05[p20]: sem efeito cadastrado | — | Todos¹ |
| [ev_00011](../resources/events/random_events/11-voce_foi_congelado.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00011_out_01[p1]: APPLY_STATUS | — | Todos¹ |
| [ev_00012](../resources/events/random_events/12-ladrao_das_sombras.tres) | Aleatório / Ruim | 4 | — | — | — | ev_00012_out_01[p25]: REMOVE_ITEM<br>ev_00012_out_02[p25]: REMOVE_ITEM<br>ev_00012_out_03[p25]: REMOVE_ITEM<br>ev_00012_out_04[p25]: REMOVE_ITEM | — | Todos¹ |
| [ev_00013](../resources/events/random_events/13-ladroes_das_sombras.tres) | Aleatório / Ruim | 4 | — | — | — | ev_00013_out_01[p25]: REMOVE_ITEM<br>ev_00013_out_02[p25]: REMOVE_ITEM<br>ev_00013_out_03[p25]: REMOVE_ITEM<br>ev_00013_out_04[p25]: REMOVE_ITEM | — | Todos¹ |
| [ev_00014](../resources/events/random_events/14-amigo_imaginario.tres) | Aleatório / Boa | 1 | — | — | — | ev_00014_out_01[p1]: REVEAL_BLOCKS | — | Todos¹ |
| [ev_00015](../resources/events/random_events/15-revelacao_lunar.tres) | Aleatório / Boa | 1 | — | — | ev_00015_out_01: é noite | ev_00015_out_01[p1]: REVEAL_BLOCKS<br>ev_00015_out_02[p1]: sem efeito cadastrado | — | Todos¹ |
| [ev_00016](../resources/events/random_events/16-mestre_artesao.tres) | Aleatório / Boa | 1 | — | — | — | ev_00016_out_01[p1]: MODIFY_EQUIPPED_ITEM_STAT | — | Todos¹ |
| [ev_00017](../resources/events/random_events/17-o_informante.tres) | Aleatório / Ambígua | 1 | — | Indireta genérica | — | ev_00017_out_01[p1]: GRANT_INFORMATION(informacao)+MODIFY_MAX_HP<br>ev_00017_out_02[p1]: sem efeito cadastrado | sorteia informacao | Completa |
| [ev_00018](../resources/events/random_events/18-calmaria.tres) | Aleatório / Boa | 1 | — | — | — | ev_00018_out_01[p2]: MODIFY_HP+REMOVE_STATUS | — | Todos¹ |
| [ev_00019](../resources/events/random_events/19-ventos_assombrosos.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00019_out_01[p50]: MODIFY_STAT<br>ev_00019_out_02[p50]: MODIFY_STAT+APPLY_STATUS | — | Todos¹ |
| [ev_00020](../resources/events/random_events/20-um_artefato_magico.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00020_out_01[p35]: TRIGGER_EVENT(ev_00021)<br>ev_00020_out_02[p35]: TRIGGER_EVENT(ev_00022)<br>ev_00020_out_03[p30]: TRIGGER_EVENT(ev_00023) | — | Todos¹ |
| [ev_00021](../resources/events/random_events/21-ataque_sobrenatural.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00021_out_01[p1]: MODIFY_MAX_HP | — | Todos¹ |
| [ev_00022](../resources/events/random_events/22-perseguicao_sobrenatural.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00022_out_01[p1]: MODIFY_HP | — | Todos¹ |
| [ev_00023](../resources/events/random_events/23-adestramento_sobrenatural.tres) | Aleatório / Boa | 1 | — | — | — | ev_00023_out_01[p1]: ADD_COMPANION | — | Todos¹ |
| [ev_00024](../resources/events/random_events/24-fantasmas_buh.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00024_out_01[p30]: GRANT_RANDOM_ITEM<br>ev_00024_out_02[p70]: MODIFY_HP+APPLY_STATUS | — | Todos¹ |
| [ev_00025](../resources/events/random_events/25-pacto_de_sangue.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00025_out_01[p1]: MODIFY_MAX_HP+GRANT_ITEM<br>ev_00025_out_02[p1]: sem efeito cadastrado | — | Todos¹ |
| [ev_00026](../resources/events/random_events/26-troca_de_corpos.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00026_out_01[p1]: SWAP_BODIES | — | Todos¹ |
| [ev_00027](../resources/events/random_events/27-poco_magico_e_reluzente.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00027_out_01[p25]: MODIFY_MAX_HP+MODIFY_STAT<br>ev_00027_out_02[p25]: MODIFY_STAT+MODIFY_MAX_HP<br>ev_00027_out_03[p20]: MODIFY_MAX_HP<br>ev_00027_out_04[p20]: MODIFY_STAT<br>ev_00027_out_05[p10]: MODIFY_MAX_HP+MODIFY_STAT | — | Todos¹ |
| [ev_00028](../resources/events/random_events/28-vortice_mortal.tres) | Aleatório / Ambígua | 1 | — | — | regra: vortice_mortal | ev_00028_out_01[p1]: CUSTOM | — | Todos¹ |
| [ev_00029](../resources/events/random_events/29-voces_foram_abduzidos.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00029_out_01[p1]: ADVANCE_DAY+CHANGE_MAP | — | Todos¹ |
| [ev_00030](../resources/events/random_events/30-voce_foi_teletransportado.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00030_out_01[p1]: TELEPORT_ENTITY | — | Todos¹ |
| [ev_00031](../resources/events/random_events/31-portal_magico.tres) | Aleatório / Boa | 1 | — | — | — | ev_00031_out_01[p1]: CHANGE_MAP<br>ev_00031_out_02[p1]: sem efeito cadastrado | — | Todos¹ |
| [ev_00032](../resources/events/random_events/32-templo_sagrado.tres) | Aleatório / Boa | 1 | — | — | — | ev_00032_out_01[p1]: REMOVE_CURSES+REMOVE_ITEM | — | Todos¹ |
| [ev_00033](../resources/events/random_events/33-tropeco_perigoso.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00033_out_01[p1]: START_COMBAT | — | Todos¹ |
| [ev_00034](../resources/events/random_events/34-raizes_traicoeiras.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00034_out_01[p1]: APPLY_STATUS | — | Todos¹ |
| [ev_00035](../resources/events/random_events/35-pulsar_da_terra.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00035_out_01[p1]: REVEAL_BLOCKS+MODIFY_HP | — | Todos¹ |
| [ev_00036](../resources/events/random_events/36-terremoto.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00036_out_01[p1]: REVEAL_BLOCKS+MODIFY_HP+APPLY_STATUS | — | Todos¹ |
| [ev_00037](../resources/events/random_events/37-visao_do_futuro.tres) | Aleatório / Boa | 1 | — | — | — | ev_00037_out_01[p1]: REVEAL_BLOCKS | — | Todos¹ |
| [ev_00038](../resources/events/random_events/38-premonicao.tres) | Aleatório / Boa | 1 | — | — | — | ev_00038_out_01[p1]: REVEAL_BLOCKS | — | Todos¹ |
| [ev_00039](../resources/events/random_events/39-danacao.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00039_out_01[p1]: MODIFY_HP | — | Todos¹ |
| [ev_00040](../resources/events/random_events/40-dois_caras_em_uma_moto.tres) | Aleatório / Ruim | 1 | — | — | — | ev_00040_out_01[p1]: APPLY_STATUS | — | Todos¹ |
| [ev_00041](../resources/events/random_events/41-traquinagens_do_saci.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00041_out_01[p1]: REPLACE_BLOCK_CONTENT | — | Todos¹ |
| [ev_00042](../resources/events/random_events/42-a_cartomante_do_olho_de_vidro.tres) | Aleatório / Boa | 1 | — | — | — | ev_00042_out_01[p1]: REVEAL_BLOCKS+REPORT_MAP_PRESENCE | — | Todos¹ |
| [ev_00043](../resources/events/random_events/43-boneco_de_madeira.tres) | Aleatório / Boa | 1 | — | — | regra: add_wooden_doll_companion | ev_00043_out_01[p1]: CUSTOM | — | Todos¹ |
| [ev_00044](../resources/events/random_events/44-duas_caras.tres) | Aleatório / Ambígua | 1 | — | Indireta genérica | — | ev_00044_out_01[p1]: GRANT_INFORMATION(informacao)<br>ev_00044_out_02[p1]: FORGET_LAST_INFORMATION<br>ev_00044_out_03[p1]: sem efeito cadastrado | sorteia informacao;remove última | Completa |
| [ev_00045](../resources/events/random_events/45-florzinha_misteriosa.tres) | Aleatório / Ambígua | 1 | — | — | regra: florzinha_misteriosa | ev_00045_out_01[p50]: CUSTOM<br>ev_00045_out_02[p50]: CUSTOM | — | Todos¹ |
| [ev_00046](../resources/events/random_events/46-loja_de_acessorios_da_miss_fortuna.tres) | Aleatório / Boa | 1 | — | — | — | ev_00046_out_01[p1]: GRANT_ITEM | — | Todos¹ |
| [ev_00047](../resources/events/random_events/47-loja_de_ferramentas_da_miss_fortuna.tres) | Aleatório / Boa | 1 | — | — | — | ev_00047_out_01[p1]: GRANT_ITEM | — | Todos¹ |
| [ev_00048](../resources/events/random_events/48-loja_de_roupas_da_miss_fortuna.tres) | Aleatório / Boa | 1 | — | — | — | ev_00048_out_01[p1]: GRANT_ITEM | — | Todos¹ |
| [ev_00049](../resources/events/random_events/49-genio_da_lampada.tres) | Aleatório / Boa | 1 | — | Indireta genérica | — | new_passive[p1]: GRANT_PASSIVE<br>status_immunity[p1]: GRANT_STATUS_IMMUNITY[disease]+GRANT_STATUS_IMMUNITY[sadness]+GRANT_STATUS_IMMUNITY[terror]<br>combat_protection[p1]: IGNORE_RANGED_CRITICAL_BONUS[ranged_critical]+GRANT_STATUS_IMMUNITY[stun]+GRANT_STATUS_IMMUNITY[bleeding]<br>remove_curses[p1]: REMOVE_CURSES<br>choose_item[p1]: GRANT_ITEM<br>random_information[p1]: GRANT_INFORMATION(informacao)<br>double_stat[p1]: MODIFY_STAT[attack]+MODIFY_MAX_HP[life]+MODIFY_HP[life]+MODIFY_STAT[stamina]<br>revive_dead_playable[p1]: REVIVE_DEAD_PLAYABLE | sorteia informacao | Todos¹; desejo Info só completa |
| [ev_00050](../resources/events/random_events/50-glitch_atemporal.tres) | Aleatório / Boa | 1 | — | — | — | ev_00050_out_01[p1]: APPLY_VISUAL_EFFECT | — | Todos¹ |
| [ev_00051](../resources/events/random_events/51-transmutacao_galiforme.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00051_out_01[p1]: APPLY_VISUAL_EFFECT | — | Todos¹ |
| [ev_00052](../resources/events/random_events/52-testemunha_ocular.tres) | Aleatório / Ambígua | 1 | — | — | — | ev_00052_out_01[p1]: APPLY_STATUS | — | Todos¹ |
| [ev_00053](../resources/events/random_events/53-carreta_da_alegria.tres) | Aleatório / Boa | 1 | — | — | — | ev_00053_out_01[p1]: MODIFY_HP+GRANT_STATUS_IMMUNITY | — | Todos¹ |
| [ev_00054](../resources/events/random_events/54-ninguem_alem_de_voce.tres) | Aleatório / Ambígua | 1 | — | — | regra: solo_active_entity_for_three_turns | ev_00054_out_01[p1]: CUSTOM | — | Todos¹ |
| [gn_00001](../resources/events/random_events/gnomes_3/01-raio_misterioso.tres) | Aleatório / Ambígua | 1 | — | — | — | gn_00001_out_01[p1]: MODIFY_STAT+MODIFY_HP<br>gn_00001_out_02[p1]: GRANT_MOVEMENT_OVERRIDE<br>gn_00001_out_03[p1]: GRANT_PASSIVE<br>gn_00001_out_04[p1]: MODIFY_HP | — | Gerado por 09 |
| [gn_00002](../resources/events/random_events/gnomes_3/02-festa_da_recuperacao.tres) | Aleatório / Boa | 1 | — | — | — | gn_00002_out_01[p1]: MODIFY_HP | — | Gerado por 09 |
| [gn_00003](../resources/events/random_events/gnomes_3/03-encontro_de_outro_distrito.tres) | Aleatório / Ruim | 1 | — | — | regra: gnome_3_start_other_district_encounter | gn_00003_out_01[p1]: CUSTOM | — | Gerado por 09 |
| [gn_00004](../resources/events/random_events/gnomes_3/04-presente_epico.tres) | Aleatório / Boa | 1 | — | — | — | gn_00004_out_01[p1]: GRANT_RANDOM_ITEM | — | Gerado por 09 |
| [gn_00005](../resources/events/random_events/gnomes_3/05-frutinha_magica.tres) | Aleatório / Ambígua | 1 | — | — | — | gn_00005_out_01[p1]: GRANT_ITEM | — | Gerado por 09 |
| [ev_00076](../resources/events/traps/76-bomba_de_gelo.tres) | Armadilha / Ruim | 1 | — | — | — | ev_00076_out_01[p1]: APPLY_STATUS | — | Todos¹ (após Info/mapa 1) |
| [ev_00077](../resources/events/traps/77-minas_explosivas.tres) | Armadilha / Ruim | 1 | — | — | — | ev_00077_out_01[p1]: MODIFY_HP+APPLY_STATUS | — | Todos¹ (após Info/mapa 1) |
| [ev_00078](../resources/events/traps/78-boca_de_lobo.tres) | Armadilha / Ruim | 1 | — | — | — | ev_00078_out_01[p1]: MODIFY_HP+APPLY_STATUS | — | Todos¹ (após Info/mapa 1) |
| [ev_00079](../resources/events/traps/79-prego_enferrujado.tres) | Armadilha / Ruim | 1 | — | — | — | ev_00079_out_01[p1]: APPLY_STATUS | — | Todos¹ (após Info/mapa 1) |
| [ev_00080](../resources/events/traps/80-fio_de_alarme.tres) | Armadilha / Ruim | 1 | — | — | — | ev_00080_out_01[p1]: START_COMBAT | — | Todos¹ (após Info/mapa 1) |

## Encadeamentos, Encontros e rotas secundárias

- `ev_00020` usa `TRIGGER_EVENT` para 21, 22 ou 23. O executor resolve o ID por `_event_by_id`, que atualmente busca **apenas** a pasta principal `random_events`; os três alvos atuais estão lá. Nenhum deles é um dos seis Eventos exclusivos. Futuras referências a subpastas ou outras categorias exigirão ampliar essa busca de forma validada.
- `ev_00009` usa `generated_events` e `Gnomes3Manager` para colocar os cinco duendes no mapa; esses cinco não pertencem ao sorteio normal. Nenhum deles é exclusivo da campanha completa.
- `ev_00041` (Saci) chama `EventExecutor._replace_map_row`, que lê pools de `PPPMapGenerator._build_pools` sem passar por `_event_is_campaign_eligible`. Essa rota agora consulta `EventCampaignEligibility` antes de formar candidatos, impedindo inserir 01–04, 17 ou 44 em curta/média. Se os elegíveis não bastarem, mantém o mapa intacto.
- `CHANGE_MAP` (Portal/abdução) volta a `GerenciaJogo.prepare_map` e ao gerador normal. Filtrar em `_event_is_campaign_eligible` cobre essa rota. O teleporte no mapa atual não sorteia Resource novo.
- `EncounterData` não possui campo de recompensa de Informação. O fluxo de vitória em `CombatManager.request_victory` recebe `rewards: Array[Resource]` e atualmente adiciona recompensa de **item** do Evento quando há uma. Não foi encontrada concessão de Informação por vitória de Encontro no código atual. **A Experiência** é dependência indireta específica de Orchestra 2/5 e 3/5 no código de recrutamento pré-combate, não um Evento da matriz: `CombatManager` consulta `in_00017`/`in_00018`; o Resource do Encontro é único. A regra alternativa por contagem global sem Orchestra continua para o Pool 3.
- A UI e `BlockManager.begin_activation` recebem Resources já colocados no mapa. `EventExecutor._on_event_requested` rejeita resolução programática não-debug de um Resource inelegível. O painel futuro de depuração precisará de uma exceção própria e explícita, sem reutilizar silenciosamente esta rota.

## Inventário de rotas de Informação e estado

| Ação | Caminho real | Lacuna para os modos |
| --- | --- | --- |
| Catálogo e mapa | `GerenciaJogo.get_information_catalog` → `CampaignState.filter_uncollected_information` → `PPPMapGenerator.generate_new_map`; 1 Informação fixa e no máximo 1 em bloco livre | Filtrar por desfechos ativos antes do sorteio, preservando as cotas. |
| Obtenção no hex | `BlockManager.confirm_information` → `GerenciaJogo.record_information_obtained` → `CampaignState.record_information_obtained` | A operação final ainda aceita duplicata e qualquer desfecho; precisa recusar e retornar motivo. |
| Obtenção por Evento | `EventExecutor._information_candidates` → `_apply_effect(GRANT_INFORMATION)` → `GerenciaJogo.record_information_obtained` | Candidatos hoje filtram ID fixo/tags e itens já obtidos, **não** desfechos ativos. |
| Esquecimento | `EventExecutor._apply_effect(FORGET_LAST_INFORMATION)` → `CampaignState.forget_last_information` | Reavaliar progresso e efeitos derivados; não tratar esquecimento como concessão. |
| Passagem de Rodada | `RoundManager` consulta `CampaignState.information_allows_round_advance` | Preservar a exigência de Informação no mapa atual; não inferir meta pela Rodada. |
| Exploração/UI | `ExplorationManager` ativa bloco; `BlockActivationPopup` confirma; `InformationArchivePanel` apenas lê estado | Não usar revelação como obtenção; UI do Gênio deve ocultar desejo inelegível, e executor deve rejeitá-lo. |
| Combate | `CombatManager` consulta IDs Orchestra para A Experiência; conclusão entrega itens | Encontro não concede Informação hoje; aplicar regra de recrutamento dependente do modo no Pool 3. |
| Persistência | Estado reside em `CampaignState` e managers; busca em `scripts/` e `addons/` não encontrou `SaveManager`, `FileAccess`, `ConfigFile` nem rotina operacional de save/load | Persistência versionada e restauração real continuam no Pool 4; não tratar referências de documentação como implementação. |

## Achados e decisões antes de alterar outros Resources

1. **Standby por valência — decisão fechada.** Se faltar uma categoria obrigatória, liberar o Evento em standby mais antigo **da valência faltante**. A implementação atual de `_release_oldest_standby_events_if_needed` já cruza standby cronológico com valências deficientes. Não trocar por outra valência e não inventar fallback. Se não houver candidato elegível, a geração falha sem instalar mapa parcial.
2. **Pools após exclusão.** Retirar os seis exclusivos de curta/média deixa, no catálogo normal bruto, 30 bons, 21 ambíguos e 23 ruins (antes: 30/27/23). Isso supera as cotas iniciais 4/5/3, mas não prova disponibilidade permanente sob standby, limite e condições. Testar geração em campanha avançada; manter a falha explícita se o pool elegível realmente esvaziar.
3. **IDs de outcomes — resolvido.** Os 119 outcomes antes sem ID receberam identificadores no formato `ID_do_Evento_out_ordinal` (por exemplo, `ev_00001_out_01`). Os oito IDs semânticos já existentes do Gênio foram preservados. A auditoria valida ausência de IDs vazios e colisões; a restrição do desejo de Informação do Gênio continua em `Outcome_information.tags`. Manter esses IDs ao reordenar outcomes futuramente.
4. **Tags e seleção de modo ligadas.** `somente_campanha_completa` está em 01–04/17/44; no Gênio está só no desejo de Informação, com marcador `contem_outcomes_restritos_por_modo` no Evento. `EventCampaignEligibility` é consumido por gerador, Saci, encadeamentos, filhos gerados, UI e executor. A escolha da tela inicial chega a `CampaignState.campaign_mode`; Completa continua padrão quando não há seleção explícita.
5. **Fonte de desfecho.** As 20 Informações usam tags de série coerentes (cinco por série). O campo `tipo` não é identificador seguro de desfecho — há valores diferentes dentro de `controle_da_mente`. Usar IDs/tags validados e uma política central, nunca título ou enum `tipo` isolado.
6. **Referências resolvidas no catálogo atual.** Não foram encontrados IDs de Evento/Informação fixos órfãos ou Resources que falham ao carregar. A busca por ID de Evento é restrita à pasta principal, mas os três `TRIGGER_EVENT` atuais apontam para ela. Reavaliar ao acrescentar novos encadeamentos.
7. **Decisões ainda bloqueantes para Pools 1–4:** política da meta/vitória durante outcome composto, derrota com apenas aliados vivos, recompensa de Informação sem candidata, save durante combate/modal, retenção de saves após vitória/derrota e relação autosave/abandono. Estão no plano principal; não afetam a classificação desta matriz.

## Como reproduzir

Executar `Godot_v4.6.2-stable_win64_console.exe --headless --path D:\\Projeto\\projeto-de-jogo --script res://scripts/tests/ppp_pool0_resource_audit.gd`. A linha `AUDIT_JSON=` contém os 85 Eventos, 20 Informações e 36 Encontros carregados, com IDs, categoria, valência, peso, condições, outcomes e referências. O campo `diagnostics` deve retornar 127 outcomes com IDs únicos, zero sem ID, nenhuma referência órfã e nenhuma falha de carregamento. Os cinco `.tres` visuais dos duendes aparecem em `other_resources`, não em `load_errors`.

O filtro por modo foi exercitado em `ppp_campaign_secondary_event_filter_test.gd`: curta/média sem os seis Eventos no mapa, Saci sem reinseri-los, filho gerado e encadeamento protegidos, Gênio com desejo de Informação indisponível nesses modos. Também passaram `ppp_map_generator_test.gd` (168 mapas), `ppp_map_event_flow_test.gd` e `ppp_genie_event_test.gd`. Nenhuma descrição narrativa de outcome foi alterada.
