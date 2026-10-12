/**
 * Secret-word bank for the Imposter party game (a Spyfall-lite played in a
 * chat). Every player but one sees the secret word; the imposter only sees
 * the localized category label as a hint and has to bluff through a round
 * of one-word clues, then may try to guess the word.
 *
 * Stable ids: a round stores the word's `id`, never its position or its
 * text. Ids are snake_case English, written by hand next to each entry, so
 * reordering, inserting or removing words never changes what an in-flight
 * or finished game points at. Never rename an id once it has shipped; add a
 * new entry instead.
 *
 * Every locale is required: players in the same room can run the app in
 * different languages, and each one sees the secret word in their own. The
 * imposter's guess is matched against the names in ALL locales, so a
 * missing or sloppy translation either hides the word from a player or
 * rejects a correct guess. Names are the word a native speaker would
 * actually say, kept to one to three words.
 *
 * Source: the location entries are adapted from the original location set
 * of the user's own spygame project (spygame/convex/locations.ts, all
 * authored fresh for that game, no commercial Spyfall text), simplified to
 * broadly understood venues. The other categories are everyday nouns added
 * for this game.
 *
 * Column order of every row below:
 *   en, tr, ar, es, fr, hi, ja, ko, pt-br, pt, sv, zh
 */

export type ImposterLocale =
  | "en"
  | "tr"
  | "ar"
  | "es"
  | "fr"
  | "hi"
  | "ja"
  | "ko"
  | "pt-br"
  | "pt"
  | "sv"
  | "zh";

export type ImposterWord = {
  id: string;
  category: string;
  names: Record<ImposterLocale, string>;
};

type Row = [
  en: string,
  tr: string,
  ar: string,
  es: string,
  fr: string,
  hi: string,
  ja: string,
  ko: string,
  ptBr: string,
  pt: string,
  sv: string,
  zh: string,
];

function names(r: Row): Record<ImposterLocale, string> {
  return {
    en: r[0],
    tr: r[1],
    ar: r[2],
    es: r[3],
    fr: r[4],
    hi: r[5],
    ja: r[6],
    ko: r[7],
    "pt-br": r[8],
    pt: r[9],
    sv: r[10],
    zh: r[11],
  };
}

function group(category: string, rows: Record<string, Row>): ImposterWord[] {
  return Object.entries(rows).map(([id, r]) => ({ id, category, names: names(r) }));
}

const CATEGORY_ROWS: Record<string, Row> = {
  places: ["Places", "Mekanlar", "أماكن", "Lugares", "Lieux", "जगहें", "場所", "장소", "Lugares", "Lugares", "Platser", "地点"],
  transport: ["Transport", "Ulaşım", "مواصلات", "Transporte", "Transports", "परिवहन", "乗り物", "탈것", "Transporte", "Transportes", "Fordon", "交通工具"],
  food: ["Food", "Yiyecekler", "طعام", "Comida", "Nourriture", "खाना", "食べ物", "음식", "Comida", "Comida", "Mat", "食物"],
  animals: ["Animals", "Hayvanlar", "حيوانات", "Animales", "Animaux", "जानवर", "動物", "동물", "Animais", "Animais", "Djur", "动物"],
  objects: ["Objects", "Eşyalar", "أشياء", "Objetos", "Objets", "चीज़ें", "モノ", "물건", "Objetos", "Objetos", "Föremål", "物品"],
  activities: ["Activities", "Aktiviteler", "أنشطة", "Actividades", "Activités", "गतिविधियाँ", "アクティビティ", "활동", "Atividades", "Atividades", "Aktiviteter", "活动"],
  jobs: ["Jobs", "Meslekler", "مهن", "Profesiones", "Métiers", "पेशे", "職業", "직업", "Profissões", "Profissões", "Yrken", "职业"],
  sports: ["Sports", "Sporlar", "رياضات", "Deportes", "Sports", "खेल", "スポーツ", "스포츠", "Esportes", "Desportos", "Sporter", "运动"],
  occasions: ["Occasions", "Etkinlikler", "مناسبات", "Eventos", "Événements", "अवसर", "イベント", "행사", "Eventos", "Eventos", "Tillfällen", "场合"],
  nature: ["Nature", "Doğa", "طبيعة", "Naturaleza", "Nature", "प्रकृति", "自然", "자연", "Natureza", "Natureza", "Natur", "大自然"],
};

export const IMPOSTER_CATEGORIES: readonly string[] = Object.keys(CATEGORY_ROWS);

export const IMPOSTER_CATEGORY_NAMES: Record<string, Record<ImposterLocale, string>> =
  Object.fromEntries(Object.entries(CATEGORY_ROWS).map(([id, r]) => [id, names(r)]));

const PLACES = group("places", {
  coastal_beach: ["Beach", "Plaj", "شاطئ", "Playa", "Plage", "समुद्र तट", "ビーチ", "해변", "Praia", "Praia", "Strand", "海滩"],
  ski_resort: ["Ski Resort", "Kayak Merkezi", "منتجع تزلج", "Estación de esquí", "Station de ski", "स्की रिसॉर्ट", "スキー場", "스키장", "Estação de esqui", "Estância de esqui", "Skidort", "滑雪场"],
  hospital: ["Hospital", "Hastane", "مستشفى", "Hospital", "Hôpital", "अस्पताल", "病院", "병원", "Hospital", "Hospital", "Sjukhus", "医院"],
  hotel: ["Hotel", "Otel", "فندق", "Hotel", "Hôtel", "होटल", "ホテル", "호텔", "Hotel", "Hotel", "Hotell", "酒店"],
  space_station: ["Space Station", "Uzay İstasyonu", "محطة فضاء", "Estación espacial", "Station spatiale", "अंतरिक्ष स्टेशन", "宇宙ステーション", "우주 정거장", "Estação espacial", "Estação espacial", "Rymdstation", "空间站"],
  spa: ["Spa", "Spa", "منتجع صحي", "Spa", "Spa", "स्पा", "スパ", "스파", "Spa", "Spa", "Spa", "水疗中心"],
  amusement_park: ["Amusement Park", "Lunapark", "مدينة ملاهي", "Parque de atracciones", "Parc d'attractions", "मनोरंजन पार्क", "遊園地", "놀이공원", "Parque de diversões", "Parque de diversões", "Nöjesfält", "游乐园"],
  bank: ["Bank", "Banka", "بنك", "Banco", "Banque", "बैंक", "銀行", "은행", "Banco", "Banco", "Bank", "银行"],
  theater: ["Theater", "Tiyatro", "مسرح", "Teatro", "Théâtre", "थिएटर", "劇場", "극장", "Teatro", "Teatro", "Teater", "剧院"],
  police_station: ["Police Station", "Karakol", "مركز شرطة", "Comisaría", "Commissariat", "पुलिस स्टेशन", "警察署", "경찰서", "Delegacia", "Esquadra", "Polisstation", "警察局"],
  restaurant: ["Restaurant", "Restoran", "مطعم", "Restaurante", "Restaurant", "रेस्टोरेंट", "レストラン", "식당", "Restaurante", "Restaurante", "Restaurang", "餐厅"],
  bakery: ["Bakery", "Fırın", "مخبز", "Panadería", "Boulangerie", "बेकरी", "パン屋", "빵집", "Padaria", "Padaria", "Bageri", "面包店"],
  cafe: ["Café", "Kafe", "مقهى", "Cafetería", "Café", "कैफ़े", "カフェ", "카페", "Cafeteria", "Café", "Kafé", "咖啡馆"],
  museum: ["Museum", "Müze", "متحف", "Museo", "Musée", "संग्रहालय", "博物館", "박물관", "Museu", "Museu", "Museum", "博物馆"],
  market: ["Market", "Pazar", "سوق", "Mercado", "Marché", "बाज़ार", "市場", "시장", "Mercado", "Mercado", "Marknad", "市场"],
  castle: ["Castle", "Kale", "قلعة", "Castillo", "Château", "किला", "お城", "성", "Castelo", "Castelo", "Slott", "城堡"],
  stadium: ["Stadium", "Stadyum", "ملعب", "Estadio", "Stade", "स्टेडियम", "スタジアム", "경기장", "Estádio", "Estádio", "Stadion", "体育场"],
  shopping_mall: ["Shopping Mall", "Alışveriş Merkezi", "مركز تسوق", "Centro comercial", "Centre commercial", "शॉपिंग मॉल", "ショッピングモール", "쇼핑몰", "Shopping", "Centro comercial", "Köpcentrum", "购物中心"],
  farm: ["Farm", "Çiftlik", "مزرعة", "Granja", "Ferme", "खेत", "農場", "농장", "Fazenda", "Quinta", "Bondgård", "农场"],
  prison: ["Prison", "Hapishane", "سجن", "Cárcel", "Prison", "जेल", "刑務所", "감옥", "Prisão", "Prisão", "Fängelse", "监狱"],
  school: ["School", "Okul", "مدرسة", "Escuela", "École", "स्कूल", "学校", "학교", "Escola", "Escola", "Skola", "学校"],
  library: ["Library", "Kütüphane", "مكتبة", "Biblioteca", "Bibliothèque", "पुस्तकालय", "図書館", "도서관", "Biblioteca", "Biblioteca", "Bibliotek", "图书馆"],
  airport: ["Airport", "Havalimanı", "مطار", "Aeropuerto", "Aéroport", "हवाई अड्डा", "空港", "공항", "Aeroporto", "Aeroporto", "Flygplats", "机场"],
  zoo: ["Zoo", "Hayvanat Bahçesi", "حديقة حيوانات", "Zoológico", "Zoo", "चिड़ियाघर", "動物園", "동물원", "Zoológico", "Jardim zoológico", "Djurpark", "动物园"],
  supermarket: ["Supermarket", "Süpermarket", "سوبرماركت", "Supermercado", "Supermarché", "सुपरमार्केट", "スーパー", "마트", "Supermercado", "Supermercado", "Mataffär", "超市"],
  cinema: ["Cinema", "Sinema", "سينما", "Cine", "Cinéma", "सिनेमा हॉल", "映画館", "영화관", "Cinema", "Cinema", "Biograf", "电影院"],
  pyramid: ["Pyramid", "Piramit", "هرم", "Pirámide", "Pyramide", "पिरामिड", "ピラミッド", "피라미드", "Pirâmide", "Pirâmide", "Pyramid", "金字塔"],
});

const TRANSPORT = group("transport", {
  airplane: ["Airplane", "Uçak", "طائرة", "Avión", "Avion", "हवाई जहाज़", "飛行機", "비행기", "Avião", "Avião", "Flygplan", "飞机"],
  cruise_ship: ["Cruise Ship", "Yolcu Gemisi", "سفينة سياحية", "Crucero", "Paquebot", "क्रूज़ जहाज़", "クルーズ船", "유람선", "Navio de cruzeiro", "Navio de cruzeiro", "Kryssningsfartyg", "游轮"],
  submarine: ["Submarine", "Denizaltı", "غواصة", "Submarino", "Sous-marin", "पनडुब्बी", "潜水艦", "잠수함", "Submarino", "Submarino", "Ubåt", "潜水艇"],
  pirate_ship: ["Pirate Ship", "Korsan Gemisi", "سفينة قراصنة", "Barco pirata", "Bateau pirate", "समुद्री डाकू जहाज़", "海賊船", "해적선", "Navio pirata", "Navio pirata", "Piratskepp", "海盗船"],
  subway_train: ["Subway Train", "Metro", "مترو", "Metro", "Métro", "मेट्रो", "地下鉄", "지하철", "Metrô", "Metro", "Tunnelbana", "地铁"],
  taxi: ["Taxi", "Taksi", "تاكسي", "Taxi", "Taxi", "टैक्सी", "タクシー", "택시", "Táxi", "Táxi", "Taxi", "出租车"],
  bus: ["Bus", "Otobüs", "حافلة", "Autobús", "Bus", "बस", "バス", "버스", "Ônibus", "Autocarro", "Buss", "公交车"],
  train: ["Train", "Tren", "قطار", "Tren", "Train", "ट्रेन", "電車", "기차", "Trem", "Comboio", "Tåg", "火车"],
  cable_car: ["Cable Car", "Teleferik", "تلفريك", "Teleférico", "Téléphérique", "रोपवे", "ロープウェイ", "케이블카", "Teleférico", "Teleférico", "Linbana", "缆车"],
  bicycle: ["Bicycle", "Bisiklet", "دراجة هوائية", "Bicicleta", "Vélo", "साइकिल", "自転車", "자전거", "Bicicleta", "Bicicleta", "Cykel", "自行车"],
  motorcycle: ["Motorcycle", "Motosiklet", "دراجة نارية", "Moto", "Moto", "मोटरसाइकिल", "バイク", "오토바이", "Moto", "Mota", "Motorcykel", "摩托车"],
  helicopter: ["Helicopter", "Helikopter", "مروحية", "Helicóptero", "Hélicoptère", "हेलीकॉप्टर", "ヘリコプター", "헬리콥터", "Helicóptero", "Helicóptero", "Helikopter", "直升机"],
  hot_air_balloon: ["Hot Air Balloon", "Sıcak Hava Balonu", "منطاد", "Globo aerostático", "Montgolfière", "हॉट एयर बैलून", "熱気球", "열기구", "Balão de ar quente", "Balão de ar quente", "Luftballong", "热气球"],
  ambulance: ["Ambulance", "Ambulans", "سيارة إسعاف", "Ambulancia", "Ambulance", "एम्बुलेंस", "救急車", "구급차", "Ambulância", "Ambulância", "Ambulans", "救护车"],
  tractor: ["Tractor", "Traktör", "جرار", "Tractor", "Tracteur", "ट्रैक्टर", "トラクター", "트랙터", "Trator", "Trator", "Traktor", "拖拉机"],
  car: ["Car", "Araba", "سيارة", "Coche", "Voiture", "कार", "車", "자동차", "Carro", "Carro", "Bil", "汽车"],
  truck: ["Truck", "Kamyon", "شاحنة", "Camión", "Camion", "ट्रक", "トラック", "트럭", "Caminhão", "Camião", "Lastbil", "卡车"],
});

const FOOD = group("food", {
  pizza: ["Pizza", "Pizza", "بيتزا", "Pizza", "Pizza", "पिज़्ज़ा", "ピザ", "피자", "Pizza", "Pizza", "Pizza", "披萨"],
  sushi: ["Sushi", "Suşi", "سوشي", "Sushi", "Sushi", "सुशी", "寿司", "초밥", "Sushi", "Sushi", "Sushi", "寿司"],
  hamburger: ["Hamburger", "Hamburger", "برغر", "Hamburguesa", "Hamburger", "बर्गर", "ハンバーガー", "햄버거", "Hambúrguer", "Hambúrguer", "Hamburgare", "汉堡"],
  ice_cream: ["Ice Cream", "Dondurma", "آيس كريم", "Helado", "Glace", "आइसक्रीम", "アイスクリーム", "아이스크림", "Sorvete", "Gelado", "Glass", "冰淇淋"],
  chocolate: ["Chocolate", "Çikolata", "شوكولاتة", "Chocolate", "Chocolat", "चॉकलेट", "チョコレート", "초콜릿", "Chocolate", "Chocolate", "Choklad", "巧克力"],
  cheese: ["Cheese", "Peynir", "جبن", "Queso", "Fromage", "चीज़", "チーズ", "치즈", "Queijo", "Queijo", "Ost", "奶酪"],
  banana: ["Banana", "Muz", "موز", "Plátano", "Banane", "केला", "バナナ", "바나나", "Banana", "Banana", "Banan", "香蕉"],
  apple: ["Apple", "Elma", "تفاح", "Manzana", "Pomme", "सेब", "りんご", "사과", "Maçã", "Maçã", "Äpple", "苹果"],
  watermelon: ["Watermelon", "Karpuz", "بطيخ", "Sandía", "Pastèque", "तरबूज़", "スイカ", "수박", "Melancia", "Melancia", "Vattenmelon", "西瓜"],
  strawberry: ["Strawberry", "Çilek", "فراولة", "Fresa", "Fraise", "स्ट्रॉबेरी", "イチゴ", "딸기", "Morango", "Morango", "Jordgubbe", "草莓"],
  popcorn: ["Popcorn", "Patlamış Mısır", "فشار", "Palomitas", "Pop-corn", "पॉपकॉर्न", "ポップコーン", "팝콘", "Pipoca", "Pipocas", "Popcorn", "爆米花"],
  pasta: ["Pasta", "Makarna", "معكرونة", "Pasta", "Pâtes", "पास्ता", "パスタ", "파스타", "Macarrão", "Massa", "Pasta", "意大利面"],
  soup: ["Soup", "Çorba", "شوربة", "Sopa", "Soupe", "सूप", "スープ", "수프", "Sopa", "Sopa", "Soppa", "汤"],
  egg: ["Egg", "Yumurta", "بيضة", "Huevo", "Œuf", "अंडा", "卵", "달걀", "Ovo", "Ovo", "Ägg", "鸡蛋"],
  honey: ["Honey", "Bal", "عسل", "Miel", "Miel", "शहद", "はちみつ", "꿀", "Mel", "Mel", "Honung", "蜂蜜"],
  tea: ["Tea", "Çay", "شاي", "Té", "Thé", "चाय", "お茶", "차", "Chá", "Chá", "Te", "茶"],
  salad: ["Salad", "Salata", "سلطة", "Ensalada", "Salade", "सलाद", "サラダ", "샐러드", "Salada", "Salada", "Sallad", "沙拉"],
  cake: ["Cake", "Kek", "كعكة", "Pastel", "Gâteau", "केक", "ケーキ", "케이크", "Bolo", "Bolo", "Tårta", "蛋糕"],
  french_fries: ["French Fries", "Patates Kızartması", "بطاطس مقلية", "Papas fritas", "Frites", "फ्रेंच फ्राइज़", "フライドポテト", "감자튀김", "Batata frita", "Batatas fritas", "Pommes frites", "薯条"],
  carrot: ["Carrot", "Havuç", "جزر", "Zanahoria", "Carotte", "गाजर", "にんじん", "당근", "Cenoura", "Cenoura", "Morot", "胡萝卜"],
});

const ANIMALS = group("animals", {
  dog: ["Dog", "Köpek", "كلب", "Perro", "Chien", "कुत्ता", "犬", "개", "Cachorro", "Cão", "Hund", "狗"],
  cat: ["Cat", "Kedi", "قطة", "Gato", "Chat", "बिल्ली", "猫", "고양이", "Gato", "Gato", "Katt", "猫"],
  horse: ["Horse", "At", "حصان", "Caballo", "Cheval", "घोड़ा", "馬", "말", "Cavalo", "Cavalo", "Häst", "马"],
  cow: ["Cow", "İnek", "بقرة", "Vaca", "Vache", "गाय", "牛", "소", "Vaca", "Vaca", "Ko", "奶牛"],
  lion: ["Lion", "Aslan", "أسد", "León", "Lion", "शेर", "ライオン", "사자", "Leão", "Leão", "Lejon", "狮子"],
  elephant: ["Elephant", "Fil", "فيل", "Elefante", "Éléphant", "हाथी", "ゾウ", "코끼리", "Elefante", "Elefante", "Elefant", "大象"],
  giraffe: ["Giraffe", "Zürafa", "زرافة", "Jirafa", "Girafe", "जिराफ़", "キリン", "기린", "Girafa", "Girafa", "Giraff", "长颈鹿"],
  monkey: ["Monkey", "Maymun", "قرد", "Mono", "Singe", "बंदर", "サル", "원숭이", "Macaco", "Macaco", "Apa", "猴子"],
  penguin: ["Penguin", "Penguen", "بطريق", "Pingüino", "Pingouin", "पेंगुइन", "ペンギン", "펭귄", "Pinguim", "Pinguim", "Pingvin", "企鹅"],
  shark: ["Shark", "Köpekbalığı", "قرش", "Tiburón", "Requin", "शार्क", "サメ", "상어", "Tubarão", "Tubarão", "Haj", "鲨鱼"],
  dolphin: ["Dolphin", "Yunus", "دلفين", "Delfín", "Dauphin", "डॉल्फ़िन", "イルカ", "돌고래", "Golfinho", "Golfinho", "Delfin", "海豚"],
  octopus: ["Octopus", "Ahtapot", "أخطبوط", "Pulpo", "Pieuvre", "ऑक्टोपस", "タコ", "문어", "Polvo", "Polvo", "Bläckfisk", "章鱼"],
  snake: ["Snake", "Yılan", "ثعبان", "Serpiente", "Serpent", "साँप", "ヘビ", "뱀", "Cobra", "Cobra", "Orm", "蛇"],
  frog: ["Frog", "Kurbağa", "ضفدع", "Rana", "Grenouille", "मेंढक", "カエル", "개구리", "Sapo", "Sapo", "Groda", "青蛙"],
  owl: ["Owl", "Baykuş", "بومة", "Búho", "Hibou", "उल्लू", "フクロウ", "부엉이", "Coruja", "Coruja", "Uggla", "猫头鹰"],
  bee: ["Bee", "Arı", "نحلة", "Abeja", "Abeille", "मधुमक्खी", "ハチ", "벌", "Abelha", "Abelha", "Bi", "蜜蜂"],
  butterfly: ["Butterfly", "Kelebek", "فراشة", "Mariposa", "Papillon", "तितली", "チョウ", "나비", "Borboleta", "Borboleta", "Fjäril", "蝴蝶"],
  camel: ["Camel", "Deve", "جمل", "Camello", "Chameau", "ऊँट", "ラクダ", "낙타", "Camelo", "Camelo", "Kamel", "骆驼"],
  kangaroo: ["Kangaroo", "Kanguru", "كنغر", "Canguro", "Kangourou", "कंगारू", "カンガルー", "캥거루", "Canguru", "Canguru", "Känguru", "袋鼠"],
  turtle: ["Turtle", "Kaplumbağa", "سلحفاة", "Tortuga", "Tortue", "कछुआ", "カメ", "거북이", "Tartaruga", "Tartaruga", "Sköldpadda", "乌龟"],
  rabbit: ["Rabbit", "Tavşan", "أرنب", "Conejo", "Lapin", "खरगोश", "ウサギ", "토끼", "Coelho", "Coelho", "Kanin", "兔子"],
});

const OBJECTS = group("objects", {
  umbrella: ["Umbrella", "Şemsiye", "مظلة", "Paraguas", "Parapluie", "छाता", "傘", "우산", "Guarda-chuva", "Guarda-chuva", "Paraply", "雨伞"],
  mirror: ["Mirror", "Ayna", "مرآة", "Espejo", "Miroir", "आईना", "鏡", "거울", "Espelho", "Espelho", "Spegel", "镜子"],
  clock: ["Clock", "Saat", "ساعة", "Reloj", "Horloge", "घड़ी", "時計", "시계", "Relógio", "Relógio", "Klocka", "时钟"],
  key: ["Key", "Anahtar", "مفتاح", "Llave", "Clé", "चाबी", "鍵", "열쇠", "Chave", "Chave", "Nyckel", "钥匙"],
  candle: ["Candle", "Mum", "شمعة", "Vela", "Bougie", "मोमबत्ती", "ろうそく", "양초", "Vela", "Vela", "Ljus", "蜡烛"],
  camera: ["Camera", "Fotoğraf Makinesi", "كاميرا", "Cámara", "Appareil photo", "कैमरा", "カメラ", "카메라", "Câmera", "Câmara", "Kamera", "相机"],
  scissors: ["Scissors", "Makas", "مقص", "Tijeras", "Ciseaux", "कैंची", "ハサミ", "가위", "Tesoura", "Tesoura", "Sax", "剪刀"],
  pillow: ["Pillow", "Yastık", "وسادة", "Almohada", "Oreiller", "तकिया", "枕", "베개", "Travesseiro", "Almofada", "Kudde", "枕头"],
  backpack: ["Backpack", "Sırt Çantası", "حقيبة ظهر", "Mochila", "Sac à dos", "बैकपैक", "リュック", "배낭", "Mochila", "Mochila", "Ryggsäck", "背包"],
  glasses: ["Glasses", "Gözlük", "نظارة", "Gafas", "Lunettes", "चश्मा", "メガネ", "안경", "Óculos", "Óculos", "Glasögon", "眼镜"],
  toothbrush: ["Toothbrush", "Diş Fırçası", "فرشاة أسنان", "Cepillo de dientes", "Brosse à dents", "टूथब्रश", "歯ブラシ", "칫솔", "Escova de dente", "Escova de dentes", "Tandborste", "牙刷"],
  hammer: ["Hammer", "Çekiç", "مطرقة", "Martillo", "Marteau", "हथौड़ा", "ハンマー", "망치", "Martelo", "Martelo", "Hammare", "锤子"],
  telescope: ["Telescope", "Teleskop", "تلسكوب", "Telescopio", "Télescope", "दूरबीन", "望遠鏡", "망원경", "Telescópio", "Telescópio", "Teleskop", "望远镜"],
  lamp: ["Lamp", "Lamba", "مصباح", "Lámpara", "Lampe", "लैंप", "ランプ", "램프", "Luminária", "Candeeiro", "Lampa", "台灯"],
  mobile_phone: ["Mobile Phone", "Cep Telefonu", "هاتف محمول", "Móvil", "Portable", "मोबाइल फ़ोन", "スマホ", "휴대폰", "Celular", "Telemóvel", "Mobiltelefon", "手机"],
  headphones: ["Headphones", "Kulaklık", "سماعات", "Auriculares", "Casque audio", "हेडफ़ोन", "ヘッドホン", "헤드폰", "Fone de ouvido", "Auscultadores", "Hörlurar", "耳机"],
  piano: ["Piano", "Piyano", "بيانو", "Piano", "Piano", "पियानो", "ピアノ", "피아노", "Piano", "Piano", "Piano", "钢琴"],
  guitar: ["Guitar", "Gitar", "غيتار", "Guitarra", "Guitare", "गिटार", "ギター", "기타", "Violão", "Guitarra", "Gitarr", "吉他"],
  ladder: ["Ladder", "Merdiven", "سلم", "Escalera", "Échelle", "सीढ़ी", "はしご", "사다리", "Escada", "Escada", "Stege", "梯子"],
});

const ACTIVITIES = group("activities", {
  karaoke: ["Karaoke", "Karaoke", "كاريوكي", "Karaoke", "Karaoké", "कराओके", "カラオケ", "노래방", "Karaokê", "Karaoke", "Karaoke", "卡拉OK"],
  camping: ["Camping", "Kamp", "تخييم", "Camping", "Camping", "कैंपिंग", "キャンプ", "캠핑", "Acampamento", "Campismo", "Camping", "露营"],
  cooking: ["Cooking", "Yemek Yapmak", "طبخ", "Cocinar", "Cuisine", "खाना बनाना", "料理", "요리", "Cozinhar", "Cozinhar", "Matlagning", "做饭"],
  dancing: ["Dancing", "Dans", "رقص", "Bailar", "Danse", "नाचना", "ダンス", "춤", "Dança", "Dança", "Dans", "跳舞"],
  painting: ["Painting", "Resim Yapmak", "رسم", "Pintar", "Peinture", "पेंटिंग", "絵を描く", "그림 그리기", "Pintura", "Pintura", "Måla", "画画"],
  fishing: ["Fishing", "Balık Tutmak", "صيد السمك", "Pescar", "Pêche", "मछली पकड़ना", "釣り", "낚시", "Pesca", "Pesca", "Fiske", "钓鱼"],
  gardening: ["Gardening", "Bahçe İşleri", "بستنة", "Jardinería", "Jardinage", "बागवानी", "ガーデニング", "정원 가꾸기", "Jardinagem", "Jardinagem", "Trädgårdsarbete", "园艺"],
  knitting: ["Knitting", "Örgü", "حياكة", "Tejer", "Tricot", "बुनाई", "編み物", "뜨개질", "Tricô", "Tricotar", "Stickning", "织毛衣"],
  video_games: ["Video Games", "Video Oyunları", "ألعاب فيديو", "Videojuegos", "Jeux vidéo", "वीडियो गेम", "テレビゲーム", "비디오 게임", "Videogame", "Videojogos", "Tv-spel", "电子游戏"],
  hiking: ["Hiking", "Doğa Yürüyüşü", "رحلة مشي", "Senderismo", "Randonnée", "पैदल यात्रा", "ハイキング", "등산", "Trilha", "Caminhada", "Vandring", "徒步"],
  board_games: ["Board Games", "Kutu Oyunları", "ألعاب لوحية", "Juegos de mesa", "Jeux de société", "बोर्ड गेम", "ボードゲーム", "보드게임", "Jogos de tabuleiro", "Jogos de tabuleiro", "Brädspel", "桌游"],
  selfie: ["Selfie", "Selfie", "سيلفي", "Selfi", "Selfie", "सेल्फ़ी", "自撮り", "셀카", "Selfie", "Selfie", "Selfie", "自拍"],
  yoga: ["Yoga", "Yoga", "يوغا", "Yoga", "Yoga", "योग", "ヨガ", "요가", "Yoga", "Ioga", "Yoga", "瑜伽"],
  jigsaw_puzzle: ["Jigsaw Puzzle", "Yapboz", "أحجية الصور", "Rompecabezas", "Puzzle", "जिगसॉ पज़ल", "ジグソーパズル", "직소 퍼즐", "Quebra-cabeça", "Puzzle", "Pussel", "拼图"],
  sunbathing: ["Sunbathing", "Güneşlenmek", "حمام شمس", "Tomar el sol", "Bain de soleil", "धूप सेंकना", "日光浴", "일광욕", "Tomar sol", "Apanhar sol", "Sola", "晒太阳"],
});

const JOBS = group("jobs", {
  doctor: ["Doctor", "Doktor", "طبيب", "Médico", "Médecin", "डॉक्टर", "医者", "의사", "Médico", "Médico", "Läkare", "医生"],
  teacher: ["Teacher", "Öğretmen", "معلم", "Profesor", "Professeur", "शिक्षक", "先生", "선생님", "Professor", "Professor", "Lärare", "老师"],
  firefighter: ["Firefighter", "İtfaiyeci", "رجل إطفاء", "Bombero", "Pompier", "फ़ायरमैन", "消防士", "소방관", "Bombeiro", "Bombeiro", "Brandman", "消防员"],
  chef: ["Chef", "Aşçı", "طباخ", "Cocinero", "Cuisinier", "शेफ़", "シェフ", "요리사", "Cozinheiro", "Cozinheiro", "Kock", "厨师"],
  pilot: ["Pilot", "Pilot", "طيار", "Piloto", "Pilote", "पायलट", "パイロット", "조종사", "Piloto", "Piloto", "Pilot", "飞行员"],
  astronaut: ["Astronaut", "Astronot", "رائد فضاء", "Astronauta", "Astronaute", "अंतरिक्ष यात्री", "宇宙飛行士", "우주비행사", "Astronauta", "Astronauta", "Astronaut", "宇航员"],
  lifeguard: ["Lifeguard", "Cankurtaran", "منقذ", "Socorrista", "Maître-nageur", "लाइफ़गार्ड", "ライフガード", "인명구조원", "Salva-vidas", "Nadador-salvador", "Livräddare", "救生员"],
  dentist: ["Dentist", "Dişçi", "طبيب أسنان", "Dentista", "Dentiste", "डेंटिस्ट", "歯医者", "치과의사", "Dentista", "Dentista", "Tandläkare", "牙医"],
  postman: ["Postman", "Postacı", "ساعي البريد", "Cartero", "Facteur", "डाकिया", "郵便屋さん", "우체부", "Carteiro", "Carteiro", "Brevbärare", "邮递员"],
  hairdresser: ["Hairdresser", "Kuaför", "مصفف شعر", "Peluquero", "Coiffeur", "नाई", "美容師", "미용사", "Cabeleireiro", "Cabeleireiro", "Frisör", "理发师"],
  mechanic: ["Mechanic", "Tamirci", "ميكانيكي", "Mecánico", "Mécanicien", "मैकेनिक", "整備士", "정비사", "Mecânico", "Mecânico", "Mekaniker", "汽车修理工"],
  waiter: ["Waiter", "Garson", "نادل", "Camarero", "Serveur", "वेटर", "ウェイター", "웨이터", "Garçom", "Empregado de mesa", "Servitör", "服务员"],
  detective: ["Detective", "Dedektif", "محقق", "Detective", "Détective", "जासूस", "探偵", "탐정", "Detetive", "Detetive", "Detektiv", "侦探"],
  scientist: ["Scientist", "Bilim İnsanı", "عالم", "Científico", "Scientifique", "वैज्ञानिक", "科学者", "과학자", "Cientista", "Cientista", "Forskare", "科学家"],
  nurse: ["Nurse", "Hemşire", "ممرضة", "Enfermera", "Infirmière", "नर्स", "看護師", "간호사", "Enfermeira", "Enfermeira", "Sjuksköterska", "护士"],
  clown: ["Clown", "Palyaço", "مهرج", "Payaso", "Clown", "जोकर", "ピエロ", "광대", "Palhaço", "Palhaço", "Clown", "小丑"],
  tour_guide: ["Tour Guide", "Tur Rehberi", "مرشد سياحي", "Guía turístico", "Guide touristique", "टूर गाइड", "ツアーガイド", "관광 가이드", "Guia turístico", "Guia turístico", "Guide", "导游"],
  plumber: ["Plumber", "Tesisatçı", "سباك", "Fontanero", "Plombier", "प्लंबर", "配管工", "배관공", "Encanador", "Canalizador", "Rörmokare", "水管工"],
});

const SPORTS = group("sports", {
  football: ["Football", "Futbol", "كرة القدم", "Fútbol", "Football", "फ़ुटबॉल", "サッカー", "축구", "Futebol", "Futebol", "Fotboll", "足球"],
  basketball: ["Basketball", "Basketbol", "كرة السلة", "Baloncesto", "Basket", "बास्केटबॉल", "バスケットボール", "농구", "Basquete", "Basquetebol", "Basket", "篮球"],
  tennis: ["Tennis", "Tenis", "تنس", "Tenis", "Tennis", "टेनिस", "テニス", "테니스", "Tênis", "Ténis", "Tennis", "网球"],
  volleyball: ["Volleyball", "Voleybol", "كرة الطائرة", "Voleibol", "Volley", "वॉलीबॉल", "バレーボール", "배구", "Vôlei", "Voleibol", "Volleyboll", "排球"],
  swimming: ["Swimming", "Yüzme", "سباحة", "Natación", "Natation", "तैराकी", "水泳", "수영", "Natação", "Natação", "Simning", "游泳"],
  boxing: ["Boxing", "Boks", "ملاكمة", "Boxeo", "Boxe", "मुक्केबाज़ी", "ボクシング", "권투", "Boxe", "Boxe", "Boxning", "拳击"],
  golf: ["Golf", "Golf", "غولف", "Golf", "Golf", "गोल्फ़", "ゴルフ", "골프", "Golfe", "Golfe", "Golf", "高尔夫"],
  surfing: ["Surfing", "Sörf", "ركوب الأمواج", "Surf", "Surf", "सर्फ़िंग", "サーフィン", "서핑", "Surfe", "Surf", "Surfing", "冲浪"],
  bowling: ["Bowling", "Bowling", "بولينغ", "Bolos", "Bowling", "बॉलिंग", "ボウリング", "볼링", "Boliche", "Bowling", "Bowling", "保龄球"],
  table_tennis: ["Table Tennis", "Masa Tenisi", "تنس الطاولة", "Ping-pong", "Ping-pong", "टेबल टेनिस", "卓球", "탁구", "Pingue-pongue", "Ténis de mesa", "Pingis", "乒乓球"],
  baseball: ["Baseball", "Beyzbol", "بيسبول", "Béisbol", "Baseball", "बेसबॉल", "野球", "야구", "Beisebol", "Basebol", "Baseboll", "棒球"],
  marathon: ["Marathon", "Maraton", "ماراثون", "Maratón", "Marathon", "मैराथन", "マラソン", "마라톤", "Maratona", "Maratona", "Maraton", "马拉松"],
  karate: ["Karate", "Karate", "كاراتيه", "Kárate", "Karaté", "कराटे", "空手", "가라테", "Caratê", "Karaté", "Karate", "空手道"],
  ice_skating: ["Ice Skating", "Buz Pateni", "التزلج على الجليد", "Patinaje sobre hielo", "Patin à glace", "आइस स्केटिंग", "アイススケート", "스케이트", "Patinação no gelo", "Patinagem no gelo", "Skridskor", "滑冰"],
  archery: ["Archery", "Okçuluk", "رماية بالسهام", "Tiro con arco", "Tir à l'arc", "तीरंदाज़ी", "アーチェリー", "양궁", "Tiro com arco", "Tiro com arco", "Bågskytte", "射箭"],
  skateboarding: ["Skateboarding", "Kaykay", "التزلج على اللوح", "Skate", "Skate", "स्केटबोर्डिंग", "スケボー", "스케이트보드", "Skate", "Skate", "Skateboard", "滑板"],
  fencing: ["Fencing", "Eskrim", "المبارزة بالسيف", "Esgrima", "Escrime", "तलवारबाज़ी", "フェンシング", "펜싱", "Esgrima", "Esgrima", "Fäktning", "击剑"],
  gymnastics: ["Gymnastics", "Jimnastik", "جمباز", "Gimnasia", "Gymnastique", "जिम्नास्टिक", "体操", "체조", "Ginástica", "Ginástica", "Gymnastik", "体操"],
});

const OCCASIONS = group("occasions", {
  birthday: ["Birthday", "Doğum Günü", "عيد ميلاد", "Cumpleaños", "Anniversaire", "जन्मदिन", "誕生日", "생일", "Aniversário", "Aniversário", "Födelsedag", "生日"],
  wedding: ["Wedding", "Düğün", "حفل زفاف", "Boda", "Mariage", "शादी", "結婚式", "결혼식", "Casamento", "Casamento", "Bröllop", "婚礼"],
  new_year: ["New Year", "Yılbaşı", "رأس السنة", "Año Nuevo", "Nouvel An", "नया साल", "お正月", "새해", "Ano-Novo", "Ano Novo", "Nyår", "新年"],
  graduation: ["Graduation", "Mezuniyet", "تخرج", "Graduación", "Remise des diplômes", "ग्रेजुएशन", "卒業式", "졸업식", "Formatura", "Formatura", "Examen", "毕业典礼"],
  picnic: ["Picnic", "Piknik", "نزهة", "Pícnic", "Pique-nique", "पिकनिक", "ピクニック", "소풍", "Piquenique", "Piquenique", "Picknick", "野餐"],
  concert: ["Concert", "Konser", "حفلة موسيقية", "Concierto", "Concert", "कॉन्सर्ट", "コンサート", "콘서트", "Show", "Concerto", "Konsert", "演唱会"],
  fireworks: ["Fireworks", "Havai Fişek", "ألعاب نارية", "Fuegos artificiales", "Feu d'artifice", "आतिशबाज़ी", "花火", "불꽃놀이", "Fogos de artifício", "Fogo de artifício", "Fyrverkeri", "烟花"],
  job_interview: ["Job Interview", "İş Görüşmesi", "مقابلة عمل", "Entrevista de trabajo", "Entretien d'embauche", "जॉब इंटरव्यू", "面接", "면접", "Entrevista de emprego", "Entrevista de emprego", "Anställningsintervju", "面试"],
  surprise_party: ["Surprise Party", "Sürpriz Parti", "حفلة مفاجئة", "Fiesta sorpresa", "Fête surprise", "सरप्राइज़ पार्टी", "サプライズパーティー", "깜짝 파티", "Festa surpresa", "Festa surpresa", "Överraskningsfest", "惊喜派对"],
  sleepover: ["Sleepover", "Pijama Partisi", "مبيت عند الأصدقاء", "Pijamada", "Soirée pyjama", "स्लीपओवर", "お泊まり会", "파자마 파티", "Festa do pijama", "Festa do pijama", "Pyjamasparty", "睡衣派对"],
  road_trip: ["Road Trip", "Yol Gezisi", "رحلة برية", "Viaje por carretera", "Road trip", "रोड ट्रिप", "ドライブ旅行", "자동차 여행", "Viagem de carro", "Viagem de carro", "Bilsemester", "自驾游"],
  barbecue: ["Barbecue", "Mangal", "شواء", "Barbacoa", "Barbecue", "बारबेक्यू", "バーベキュー", "바비큐", "Churrasco", "Churrasco", "Grillfest", "烧烤"],
  vacation: ["Vacation", "Tatil", "عطلة", "Vacaciones", "Vacances", "छुट्टी", "休暇", "휴가", "Férias", "Férias", "Semester", "度假"],
  family_dinner: ["Family Dinner", "Aile Yemeği", "عشاء عائلي", "Cena familiar", "Dîner en famille", "फ़ैमिली डिनर", "家族の夕食", "가족 식사", "Jantar em família", "Jantar de família", "Familjemiddag", "家庭聚餐"],
  fashion_show: ["Fashion Show", "Defile", "عرض أزياء", "Desfile de moda", "Défilé de mode", "फ़ैशन शो", "ファッションショー", "패션쇼", "Desfile de moda", "Desfile de moda", "Modevisning", "时装秀"],
});

const NATURE = group("nature", {
  volcano: ["Volcano", "Yanardağ", "بركان", "Volcán", "Volcan", "ज्वालामुखी", "火山", "화산", "Vulcão", "Vulcão", "Vulkan", "火山"],
  rainbow: ["Rainbow", "Gökkuşağı", "قوس قزح", "Arcoíris", "Arc-en-ciel", "इंद्रधनुष", "虹", "무지개", "Arco-íris", "Arco-íris", "Regnbåge", "彩虹"],
  waterfall: ["Waterfall", "Şelale", "شلال", "Cascada", "Cascade", "झरना", "滝", "폭포", "Cachoeira", "Cascata", "Vattenfall", "瀑布"],
  desert: ["Desert", "Çöl", "صحراء", "Desierto", "Désert", "रेगिस्तान", "砂漠", "사막", "Deserto", "Deserto", "Öken", "沙漠"],
  island: ["Island", "Ada", "جزيرة", "Isla", "Île", "द्वीप", "島", "섬", "Ilha", "Ilha", "Ö", "岛屿"],
  rainforest: ["Rainforest", "Yağmur Ormanı", "غابة مطيرة", "Selva", "Forêt tropicale", "वर्षावन", "熱帯雨林", "열대우림", "Floresta tropical", "Floresta tropical", "Regnskog", "雨林"],
  cave: ["Cave", "Mağara", "كهف", "Cueva", "Grotte", "गुफा", "洞窟", "동굴", "Caverna", "Gruta", "Grotta", "山洞"],
  glacier: ["Glacier", "Buzul", "نهر جليدي", "Glaciar", "Glacier", "ग्लेशियर", "氷河", "빙하", "Geleira", "Glaciar", "Glaciär", "冰川"],
  mountain: ["Mountain", "Dağ", "جبل", "Montaña", "Montagne", "पहाड़", "山", "산", "Montanha", "Montanha", "Berg", "山"],
  river: ["River", "Nehir", "نهر", "Río", "Rivière", "नदी", "川", "강", "Rio", "Rio", "Flod", "河流"],
  thunderstorm: ["Thunderstorm", "Fırtına", "عاصفة رعدية", "Tormenta", "Orage", "तूफ़ान", "雷雨", "천둥번개", "Tempestade", "Trovoada", "Åskväder", "雷雨"],
  moon: ["Moon", "Ay", "قمر", "Luna", "Lune", "चाँद", "月", "달", "Lua", "Lua", "Måne", "月亮"],
  tornado: ["Tornado", "Hortum", "إعصار", "Tornado", "Tornade", "बवंडर", "竜巻", "토네이도", "Tornado", "Tornado", "Tornado", "龙卷风"],
  sunflower: ["Sunflower", "Ayçiçeği", "دوار الشمس", "Girasol", "Tournesol", "सूरजमुखी", "ひまわり", "해바라기", "Girassol", "Girassol", "Solros", "向日葵"],
  cactus: ["Cactus", "Kaktüs", "صبار", "Cactus", "Cactus", "कैक्टस", "サボテン", "선인장", "Cacto", "Cato", "Kaktus", "仙人掌"],
  snowman: ["Snowman", "Kardan Adam", "رجل الثلج", "Muñeco de nieve", "Bonhomme de neige", "स्नोमैन", "雪だるま", "눈사람", "Boneco de neve", "Boneco de neve", "Snögubbe", "雪人"],
  sunset: ["Sunset", "Gün Batımı", "غروب الشمس", "Atardecer", "Coucher de soleil", "सूर्यास्त", "夕日", "노을", "Pôr do sol", "Pôr do sol", "Solnedgång", "日落"],
  coral_reef: ["Coral Reef", "Mercan Resifi", "شعاب مرجانية", "Arrecife de coral", "Récif de corail", "मूंगा चट्टान", "サンゴ礁", "산호초", "Recife de coral", "Recife de coral", "Korallrev", "珊瑚礁"],
});

export const IMPOSTER_WORDS: readonly ImposterWord[] = [
  ...PLACES,
  ...TRANSPORT,
  ...FOOD,
  ...ANIMALS,
  ...OBJECTS,
  ...ACTIVITIES,
  ...JOBS,
  ...SPORTS,
  ...OCCASIONS,
  ...NATURE,
];
