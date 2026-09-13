# frozen_string_literal: true

module Axioma
  class TemplateSeeder
    # Seeds standard Tajik/Russian business templates, labels, custom attributes and teams
    def self.seed_account(account_id)
      account = Account.find_by(id: account_id)
      return unless account

      Rails.logger.info "[Axioma Seeder] Starting seeding for Account ##{account.id} (#{account.name})..."

      seed_canned_responses(account)
      seed_labels(account)
      seed_custom_attributes(account)
      seed_teams(account)

      Rails.logger.info "[Axioma Seeder] Seeding completed successfully for Account ##{account.id}!"
    end

    def self.seed_canned_responses(account)
      templates = [
        # --- Russian ---
        {
          short_code: 'привет',
          content: 'Здравствуйте! 👋 Спасибо за обращение в нашу компанию. Чем можем помочь?'
        },
        {
          short_code: 'наличие',
          content: 'Да, данный товар есть в наличии и готов к отправке!'
        },
        {
          short_code: 'доставка',
          content: "Стоимость доставки по Душанбе составляет от 15 сомони (в течение 1-3 часов).\nДоставка по регионам Таджикистана — в течение 24 часов."
        },
        {
          short_code: 'заказ',
          content: 'Спасибо за заказ! 🙏 Мы подтверждаем получение заявки. Наш специалист свяжется с вами в течение 10 минут.'
        },
        {
          short_code: 'оплата',
          content: "Реквизиты для оплаты через Корти Милли / Alif Mobi:\n• Номер кошелька/карты: +992 88 410 6161\n• Получатель: Axioma\n\nПосле оплаты, пожалуйста, отправьте квитанцию или чек в этот чат!"
        },
        {
          short_code: 'чек_принят',
          content: 'Оплата успешно получена и подтверждена! ✅ Ваш заказ передан в отдел доставки.'
        },
        {
          short_code: 'менеджер',
          content: 'Менеджер подключится к диалогу в течение нескольких минут. Пожалуйста, оставайтесь на связи!'
        },
        {
          short_code: 'спасибо',
          content: 'Спасибо за обращение! Если у вас появятся дополнительные вопросы, мы всегда рады помочь. Хорошего вам дня! 😊'
        },

        # --- Tajik ---
        {
          short_code: 'салом',
          content: 'Салом! 👋 Хуш омадед ба ширкати мо. Чӣ тавр метавонам ба шумо кӯмак кунам?'
        },
        {
          short_code: 'ҳасти',
          content: 'Бале, ин мол дар анбор ҳаст ва омодаи ирсол мебошад!'
        },
        {
          short_code: 'интиқол',
          content: "Маълумот оид ба интиқоли фармоишҳо:\n• Дар шаҳри Душанбе — дар давоми 1-3 соат (аз 15 сомонӣ)\n• Ба дигар шаҳрҳо ва ноҳияҳои ҶТ — дар давоми 24 соат\n\nМо фармоиши шуморо боэътимод мерасонем!"
        },
        {
          short_code: 'дархост',
          content: 'Ташаккур барои фармоиш! 🙏 Мо дархости шуморо қабул намудем. Менеҷери мо дар муддати кӯтоҳ бо шумо тамос мегирад.'
        },
        {
          short_code: 'корт',
          content: "Реквизитҳо барои пардохти Корти Миллӣ / Алиф Моби:\n• Рақами ҳамён: +992 88 410 6161\n• Қабулкунанда: Axioma\n\nЛутфан, пас аз пардохт чекро ба ҳамин чат фиристед!"
        },
        {
          short_code: 'чек',
          content: 'Пардохти шумо бомуваффақият қабул ва тасдиқ карда шуд! ✅ Чек ба система сабт шуд ва фармоиши шумо фавран ба кор даромад.'
        },
        {
          short_code: 'менеҷер',
          content: 'Менеҷери мо дар муддати кӯтоҳтарин ба сӯҳбат пайваст мешавад ва ба ҳамаи саволҳои шумо ҷавоб медиҳад. Лутфан, каме интизор шавед.'
        },
        {
          short_code: 'рахмат',
          content: 'Ташаккур барои муроҷиат ба ширкати мо! 🙏 Агар боз ягон савол пайдо шавад, мо ҳамеша дар хизмати шумо ҳастем. Рӯзи хуш орзумандем!'
        },
        {
          short_code: 'нархнома',
          content: "📊 Нархнома ва тарифҳои хизматрасонии мо:\n\n🟢 1. «Соҳибкор» — 189 сомонӣ / моҳ (1 рақам, 2 ҷойи корӣ)\n🔵 2. «Тиҷорат» — 349 сомонӣ / моҳ (2 рақам, 5 оператор, бот)\n🟣 3. «Корпоратсия» — 790 сомонӣ / моҳ (5+ рақам, операторони номаҳдуд)\n\n🎁 Барои ҳамаи навъҳо 3 рӯз озмоиши РОЙГОН дода мешавад!"
        }
      ]

      templates.each do |tpl|
        existing = account.canned_responses.find_by(short_code: tpl[:short_code])
        if existing
          existing.update(content: tpl[:content])
        else
          account.canned_responses.create!(short_code: tpl[:short_code], content: tpl[:content])
        end
      end
    end

    def self.seed_labels(account)
      labels_data = [
        # English / Technical tags
        { title: 'new', color: '#1E90FF', description: 'Новый диалог / Муроҷиати нав' },
        { title: 'hot', color: '#FF4757', description: 'Горячий лид / Лиди гарм (готов к покупке)' },
        { title: 'vip', color: '#9B59B6', description: 'VIP клиент / Мизоҷи муҳим' },
        { title: 'lead', color: '#FFA502', description: 'Потенциальный клиент / Лид' },
        { title: 'wholesale', color: '#2ED573', description: 'Оптовый покупатель / Харидори яклухт' },
        { title: 'repeat', color: '#00D4AA', description: 'Постоянный клиент / Мизоҷи доимӣ' },
        { title: 'payment_pending', color: '#ECCC68', description: 'Ожидает оплаты / Интизори пардохт' },
        { title: 'delivery', color: '#70A1FF', description: 'Доставка / Расонидан' },
        { title: 'complaint', color: '#FF6B81', description: 'Жалоба / Эрод ва норозигӣ' },
        { title: 'lost', color: '#747D8C', description: 'Отказ / Бой дода шуд' },

        # Russian tags
        { title: 'новый', color: '#1E90FF', description: 'Новое обращение клиента' },
        { title: 'в_работе', color: '#FFA502', description: 'Оператор обрабатывает обращение' },
        { title: 'оплачено', color: '#2ED573', description: 'Оплата подтверждена' },
        { title: 'доставка', color: '#70A1FF', description: 'Заказ в службе доставки' },

        # Tajik tags
        { title: 'лиди_гарм', color: '#FF4757', description: 'Мизоҷи омода барои харид' },
        { title: 'пардохт_шуд', color: '#2ED573', description: 'Маблағ пурра қабул карда шуд' },
        { title: 'дар_коркард', color: '#FFA502', description: 'Менеҷер дар ҳоли гуфтугӯ' },
        { title: 'интизори_пардохт', color: '#1E90FF', description: 'Счёт дода шуд, интизори чек' }
      ]

      labels_data.each do |lbl|
        existing = account.labels.find_by(title: lbl[:title])
        if existing
          existing.update(color: lbl[:color], description: lbl[:description], show_on_sidebar: true)
        else
          account.labels.create!(
            title: lbl[:title],
            color: lbl[:color],
            description: lbl[:description],
            show_on_sidebar: true
          )
        end
      end
    end

    def self.seed_custom_attributes(account)
      attrs = [
        {
          attribute_display_name: 'Категория клиента',
          attribute_key: 'client_category',
          attribute_display_type: 'list',
          attribute_model: 'contact_attribute',
          attribute_description: 'Сегментация и категория клиента для воронки продаж',
          attribute_values: [
            'Новый клиент',
            'Потенциальный клиент',
            'Постоянный клиент',
            'VIP',
            'Оптовый клиент',
            'Неактивный',
            'Проблемный'
          ]
        },
        {
          attribute_display_name: 'Шаҳр / Город',
          attribute_key: 'shahr',
          attribute_display_type: 'list',
          attribute_model: 'contact_attribute',
          attribute_description: 'Шаҳри сукунат ё фаъолияти муштарӣ',
          attribute_values: ['Душанбе', 'Хуҷанд', 'Бохтар', 'Кӯлоб', 'Истаравшан', 'Исфара', 'Турсунзода', 'Дигар']
        },
        {
          attribute_display_name: 'Номи ширкат / Компания',
          attribute_key: 'nomi_shirkat',
          attribute_display_type: 'text',
          attribute_model: 'contact_attribute',
          attribute_description: 'Номи бренди муштарӣ ё ташкилот'
        },
        {
          attribute_display_name: 'Шумораи кормандон / Размер команды',
          attribute_key: 'shumorai_operatoron',
          attribute_display_type: 'number',
          attribute_model: 'contact_attribute',
          attribute_description: 'Миқдори кормандони муштарӣ'
        },
        {
          attribute_display_name: 'Ҳолати муштарӣ / Статус лида',
          attribute_key: 'holati_mushtari',
          attribute_display_type: 'list',
          attribute_model: 'contact_attribute',
          attribute_description: 'Марҳила дар воронкаи фурӯш',
          attribute_values: ['Лиди нав', 'Дар гуфтугӯ', 'Харидор', 'Мизоҷи доимӣ', 'Рад шуд']
        },
        {
          attribute_display_name: 'Маблағи муомила (сомонӣ) / Сумма сделки',
          attribute_key: 'mablaghi_muomila',
          attribute_display_type: 'currency',
          attribute_model: 'contact_attribute',
          attribute_description: 'Ҳаҷми умумии харид бо сомонӣ'
        },
        {
          attribute_display_name: 'Қайдҳои муҳим / Заметки',
          attribute_key: 'qaydho',
          attribute_display_type: 'text',
          attribute_model: 'contact_attribute',
          attribute_description: 'Маълумоти иловагӣ ва хусусиятҳои муштарӣ'
        }
      ]

      attrs.each do |att|
        existing = account.custom_attribute_definitions.find_by(attribute_key: att[:attribute_key])
        unless existing
          account.custom_attribute_definitions.create!(att)
        end
      end
    end

    def self.seed_teams(account)
      teams = [
        {
          name: 'Шӯъбаи фурӯш (Отдел продаж)',
          description: 'Идоракунии муштариён, бастани шартномаҳо ва фурӯш',
          allow_auto_assign: true
        },
        {
          name: 'Дастгирии техникӣ (Поддержка)',
          description: 'Кӯмак дар танзими система ва масъалаҳои муштариён',
          allow_auto_assign: true
        }
      ]

      teams.each do |tm|
        existing = account.teams.find_by(name: tm[:name])
        unless existing
          account.teams.create!(tm)
        end
      end
    end
  end
end
