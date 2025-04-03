```mermaid
flowchart TB
    subgraph ProxyLayer["Прокси-слой (Upgradeable)"]
        ERC1967Proxy["ERC1967Proxy\n• Хранит состояние\n• Делегирует вызовы"] -->|Прозрачное делегирование| MultiSigImpl["MultiSig Logic\n• Логика мультисиг\n• Без состояния"]
    end

    subgraph DataModel["Модель данных"]
        MultiSigImpl --> Owners["Владельцы (owners[])\n• Адреса с правами\n• Инициализируются once"]
        MultiSigImpl --> Threshold["Порог (threshold)\n• Минимум подтверждений\n• Проверка: owners.length >= threshold"]
        MultiSigImpl --> Transactions["Транзакции (Transaction[])\n• to, value, data\n• executed, confirmationCount"]
    end

    subgraph Workflow["Жизненный цикл транзакции"]
        direction LR
        A[Владелец] -->|submitTransaction| B["• Проверка onlyOwner\n• Добавление в массив\n• Event: TransactionSubmitted"]
        B --> C[Владельцы] -->|confirmTransaction| D{"• Проверка: !executed && !isConfirmed\n• Увеличение confirmationCount"}
        D -->|confirmationCount >= threshold| E["_executeTransaction()\n• Low-level call\n• Требует success\n• Event: TransactionExecuted"]
        D -->|Иначе| F[Ожидание]
    end

    subgraph Security["Безопасность"]
        UUPS["UUPSUpgradeable\n• upgradeToAndCall()"] -->|onlyOwner| Upgrade["• Новая логика\n• Сохранение:\n  - owners\n  - transactions\n  - баланс"]
        MultiSigImpl --> Initializable["• initialize() once\n• Проверки:\n  - threshold > 0\n  - valid owners"]
    end

    External((Внешние системы)) -->|Вызовы через прокси| ERC1967Proxy
    ERC1967Proxy -->|Автоматическая| Fallback["• receive()\n• fallback()"] --> FundsDeposited["Event: FundsDeposited"]

    ProxyLayer --> Workflow
    DataModel --> Workflow
    Security --> DataModel

    classDef proxy fill:#e1f5fe,stroke:#039be5,stroke-width:2px
    classDef logic fill:#f0f4c3,stroke:#afb42b,stroke-dasharray:5
    classDef process fill:#c8e6c9,stroke:#43a047,rounded
    classDef critical fill:#ffcdd2,stroke:#e53935,dashed
    classDef data fill:#d1c4e9,stroke:#7e57c2

    class ERC1967Proxy,MultiSigImpl proxy
    class Workflow process
    class UUPS,Initializable critical
    class Owners,Threshold,Transactions data

```

# Refs
https://pkqs90.github.io/posts/gnosis-safe-walkthrough/
https://docs.openzeppelin.com/contracts/5.x/api/access#Ownable
https://docs.openzeppelin.com/contracts/5.x/api/proxy
https://docs.openzeppelin.com/contracts/5.x/api/proxy#ERC1967Utils
https://docs.openzeppelin.com/upgrades-plugins/proxies#proxy-forwarding
