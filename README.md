# AddonsWowForever

Addons propios para World of Warcraft Forever (cliente híbrido, interfaz 16001). Cada carpeta es un addon: el archivo `.toc` tiene que llamarse igual que la carpeta. Copia la carpeta a `Interface/AddOns` y reinicia el cliente la primera vez; un addon nuevo no aparece solo con `/reload`.

## SubastasForever 1.1.23

Vigila precios en la casa de subastas. Si un objeto de la lista baja de tu máximo, puedes comprarlo. Si lo tienes en las bolsas, puedes publicarlo al precio de venta que guardaste.

- `/sf` o `/subastas` abre y cierra la ventana. También al abrir la casa, si está marcado «Abrir aquí».
- Mayús-clic en un objeto, o escribe su nombre o su ID. Rellena compra máxima, venta y cantidad, y pulsa Añadir.
- Precios: `1s50c`, `50c`, `2s`, `1p50c`. Un número suelto se lee como oro (`0.15` son 15 platas).
- Ganga: el precio actual está en tu máximo o por debajo. Alto: cuesta más. La casilla de la izquierda pausa esa fila. La X la quita.
- Comprar solo se enciende con la casa abierta y si es ganga. En materiales hacen falta dos clics: Comprar y luego Confirmar. En equipo, recetas y el resto, un clic cierra la compra.
- Comprar siguiente toma la primera ganga de la lista.
- Vender se enciende si el objeto está en las bolsas, la casa está abierta y el precio de venta es al menos 1 cobre. Publica hasta la cantidad de la lista. La duración es el botón de 12 h, 24 h o 48 h.
- Escanear mira una vez todos los objetos activos. Reescanear, si está marcado, repite cada minuto con la casa abierta y avisa de gangas.
- `/sf escanear` busca precios. `/sf estado` resume la lista. `/sf cancelar` descarta una compra de materiales a medias.
- Con la casa abierta, los objetos de la mochila que se pueden subastar llevan una moneda. Esa marca no publica nada.
- El juego no deja comprar ni confirmar sin tu clic. Con la casa cerrada no hay precios nuevos ni compra ni venta.

Variables guardadas: `SubastasForeverDB`.

## WhereIs 1.6.0

Escribe un objeto y marca dónde comprarlo, farmearlo, desencantarlo o entregar una caja de Forever.

- `/whereis`, `/where`, `/donde` o `/compra` abre la ventana. `/whereis hilo burdo` busca ese objeto. `/whereis limpiar` quita los puntos. `/whereis ayuda` resume los comandos.
- Mayús-clic en un objeto de la mochila también busca.
- Busca vendedores, bichos, plantas, menas, bancos de pesca y desencantar.
- `caja`, `cajas`, `crate`, `crates` o `waylaid` marca la entrega de la caja sin tipo: Marcy Baker en Crestagrana (Alianza) o Dokimi en Los Baldíos (Horda). Mayús-clic en una caja concreta busca esa. No marca quién la tira: el drop es común y no hay campamento fijo.
- Cada resultado se marca en el mapa de la zona. En plantas, menas y bancos marca todos los puntos y pinta una ruta. Clic izquierdo en un vendedor o un bicho lo sigue en el minimapa; clic derecho en ese punto lo quita. Clic derecho en un punto del mapa quita solo ese punto.
- Quitar marcas los borra. Ocultar marcas los esconde sin perderlos.
- Al abrir un vendedor, recuerda lo que vende y el sitio exacto.
- Los porcentajes de desencantar son la tirada de ese nivel de objeto. Los de matar, desollar o pescar son una tasa habitual y cambian de un bicho a otro. Herborizar o minar ese nodo es el 100%.
- Vendedores y bichos se limitan a 15 marcas. Las zonas de nodos no.

Variables guardadas: `DondeComprarDB`.

## MisionWowhead 1.1.3

Pone un libro en cada misión del diario, del mapa de misiones y del rastreador de objetivos. Al pulsarlo abre un cuadro con el enlace de Wowhead Classic ya seleccionado, para copiarlo y abrirlo en el navegador. No abre el navegador desde el juego.

El libro se esconde si el rastreador está minimizado, si la misión no está a la vista, o si taparía las bolsas o el banco.

## CDManager 1.2.8

Muestra cortes, aturdimientos, miedos, defensivos y ofensivos de un jugador, y el tiempo que falta para que vuelvan. `LIBRE` sale cuando los cortes que conoce de esa persona están en recuperación.

En este cliente no puede anclarse a las placas de nombre ni leer el registro de combate: el juego bloquea el addon. Solo sigue a tu objetivo, el foco, el grupo, la banda, la arena y los jefes, cuando lanzan una habilidad que el addon conoce. De momento también sigue a los aliados, para poder probarlo fuera de un combate real.

Hasta que no ve un corte, no marca `LIBRE`: el corte principal podría seguir disponible. Los defensivos y ofensivos de talento no salen hasta que esa persona los usa. Las duraciones son las de Classic y pueden no coincidir con Forever. Las filas se apilan arriba de la pantalla y desaparecen a los 45 segundos sin un lanzamiento nuevo.

Al entrar, el chat dice `CDManager 1.2.8 cargado` si esta versión es la que está activa.

## Capa 1.0.1

Muestra en qué capa de Forever estás y pide el cambio a otra. La capa sale del identificador de zona de un NPC, vehículo u objeto. La letra (A, B, C…) es local: ordena las capas que tú has visto en esa zona. El número es el identificador real. Arriba de la pantalla hay una etiqueta arrastrable; un clic abre el panel.

- `/capa` abre el panel.
- `/capa pedir` pide un cambio. `/capa B` pide esa letra. `/capa 2105` pide ese identificador. Un número menor de 100 se trata como posición de letra.
- `/capa hermandad` (también `guild` o `gremio`) pregunta a la hermandad y lista quién está en cada capa.
- `/capa anfitrion` enciende o apaga el modo anfitrión. Encendido, invitas a quien pida tu capa actual, si no estás en combate, en una instancia o en banda, y el grupo no está lleno. Viene encendido.
- El cambio ocurre al aceptar la invitación de alguien que ya está en esa capa. Al salir del grupo vuelves a la tuya. El addon no puede dejarte en la capa ajena.

Variables guardadas: `CapaDB`.

## Campamentos 1.0.4

Lista los bufos de los campamentos de Forever y marca cuáles tienes. El cliente los junta en un solo aura; el addon lee ese aura y su descripción.

- El botón del minimapa abre y cierra la ventana. También `/campamentos` o `/camp`. Se puede arrastrar, y el botón del minimapa se mueve alrededor de él. Escape la cierra.
- Verde: lo recogiste en el campamento. Amarillo: no está el del campamento porque ya lo cubre el bufo de clase, y no se acumulan. Rojo: te falta.
- Arriba dice cuántos de los nueve llevas y cuánto les queda. Si hay una hoguera cerca, o estás sentado esperando el minuto, también lo indica.
- Cada fila dice el objeto y la profesión que hay que colocar en la hoguera. Hay que sentarse un minuto; la tienda de descanso basta con medio y solo se puede recoger una vez por hora.
- El pie indica los huecos de cada hoguera, en líneas separadas: básica 3 objetos (Cocina 1), oficial 5 (Cocina 140) y experto 10 (Cocina 220). El fuego no cuenta. Cada persona coloca un objeto y comparten una hora. El robot y los talleres ocupan un hueco y no dan bufo.
- `/campamentos auras` escribe en el chat los bufos activos, por si el cliente no detalla los efectos.

Los de clase que tapan a los del campamento: Reyes (paladín, desde nivel 20), Entereza (sacerdote), Intelecto Arcano (mago), Espíritu divino (sacerdote, desde nivel 30), Marca de lo Salvaje (druida), Sabiduría y Poderío (paladín), Fuerza de la tierra (chamán, rama Mejora) y el crítico del lechúcico lunar (Equilibrio, 31 puntos) o de Líder de la manada (Feral, 21 puntos). El paladín solo pone una bendición por persona. La tienda no la cubre ninguna clase.

Variables guardadas: `CampamentosDB`.

## PvP 1.0.0

Marca en el mapa dónde apuntarte a cada campo de batalla de Forever. Solo muestra los puntos de tu facción.

- El botón del minimapa abre la ventana. También `/pvp`. Se puede arrastrar, y el botón se mueve alrededor del minimapa. Escape la cierra.
- Garganta Grito de Guerra: 10 contra 10, desde nivel 10. Entrada en la Arboleda Ala de Plata (Alianza) o en el Campamento Mor'shan (Horda), y maestros de batalla en las tres ciudades.
- Cuenca de Arathi: 15 contra 15, desde nivel 20. Entrada en el Refugio de la Zaga o en Sentencia.
- Valle de Alterac: 40 contra 40, niveles 51 a 60. Entrada en las Montañas de Alterac.
- Islas Lanza Negra: 15 contra 15, desde nivel 30. La cola está en las ciudades, no en el campo.
- Al elegir un campo, el mapa se abre en el primer punto y salen botones para la entrada y para cada ciudad. El pin solo se ve en el mapa de esa zona. Al pasar el ratón dice con quién hablar. Cerrar la ventana no quita las marcas.

Variables guardadas: `PvPDB`.
