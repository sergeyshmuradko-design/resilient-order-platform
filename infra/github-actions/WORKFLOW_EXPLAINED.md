# Два workflow и один коммит конфигурации

## Что означает выбор

| В Git | Choice | Результат |
| --- | --- | --- |
| false | enable | Один коммит true; Argo создаёт Application и ресурсы |
| true | disable | Один коммит false; Argo удаляет Application каскадно |
| true | enable | Без нового коммита и переустановки |
| false | disable | Без нового коммита |
| любое | keep | Сохранить значение из Git |

Повторный запуск всё равно ожидает нужную revision, Synced и Healthy.
Если прошлый запуск завершился по таймауту после push, желаемое состояние уже в
Git: Argo продолжает работу, а повторный workflow только проверяет результат.
Нет промежуточных состояний и коммитов удаления.

## Bootstrap

`codespaces-cluster-bootstrap` принимает только `mode: plan / apply / destroy`.

1. GitHub-hosted job через gh api проверяет admin-права инициатора.
2. Self-hosted job использует общий concurrency group с deploy, чтобы они не
   меняли один кластер одновременно. Runner нужно запустить заранее.
3. Checkout с clean=false сохраняет локальный Terraform state.
4. Setup Terraform устанавливает закреплённую версию; init загружает провайдеры,
   validate проверяет конфигурацию, plan показывает план k3d.
5. Apply создаёт k3d, затем устанавливает Argo и bootstrap Helm release.
6. Bootstrap создаёт root Application, AppProject и настройки доступа.
7. Argo читает Git и разворачивает сохранённую selection. ESO уже на базовом
   этапе обращается к Infisical, независимо от наличия прикладных сервисов.
8. Workflow ждёт Synced/Healthy root.

Plan пока показывает только k3d; platform plan рассчитывается внутри apply после
появления Kubernetes API. Это не полноценный offline-plan всего стека.

## Deploy

`codespaces-platform-deploy` не запускает Terraform.

| Шаг | Что делает |
| --- | --- |
| Authorize admin | Проверяет права инициатора |
| GitHub App token | Получает короткоживущий токен с Contents: write |
| Checkout | Загружает выбранную ветку и историю для rebase |
| Check cluster and watched branch | Проверяет контекст и ветку root |
| Install pinned yq | Скачивает бинарник в RUNNER_TEMP, без демона |
| Configure GitOps author | Устанавливает bot-автора, email ничего не отправляет |
| Apply choices | Вычисляет конечное состояние, делает максимум один коммит, ждёт Argo |

`COMPONENT_INPUTS` получает JSON workflow inputs. `selection-plan.jq`
проверяет ключи/значения и зависимости сервисов, возвращает before/target/changed.
Например, нельзя отключить PostgreSQL, оставив order-service включённым.

`apply-selection.sh`:
1. Вычисляет target через jq.
2. При отключении Strimzi проверяет отсутствие Kafka CR, потому что этот выбор
   пока управляет только оператором, а не самим Kafka.
3. Выводит таблицу Before / Choice / Target в job summary.
4. При changed=true обновляет YAML через yq, проверяет Helm, коммитит и делает
   rebase. Повторно сверяет target после rebase, затем делает push без force.
5. Обновляет кэш root и ждёт revision, Synced и Healthy. Сам ресурсы не удаляет.

Нужны variable GITOPS_APP_CLIENT_ID и secret GITOPS_APP_PRIVATE_KEY.
GitHub App должен быть установлен на репозиторий, иметь Contents: write и
разрешённый обход branch rules для конфигурационных коммитов.
Infisical Variables/Secrets остаются прежними.

Если посторонний коммит обогнал ожидаемый SHA, ожидание точной revision может
истечь, даже если более новая конфигурация уже работает. Проверьте root и
повторите workflow. Общая concurrency не блокирует ручные Git push.

## Почему порядок теперь задаётся без скрипта

Брокер, топология, операторы, политики и каждый сервис представлены отдельными
Applications. Отключение убирает Application из результата root Helm chart,
а не только меняет флаг внутри остающегося общего Application.

Argo prune удаляет Applications в обратном порядке waves. Foreground finalizer
оставляет каждую Application существовать, пока её ресурсы не удалятся:

```text
сервисы -> RabbitMQ topology -> RabbitmqCluster -> RabbitMQ operators -> cert-manager
Kyverno policies -> Kyverno operator
```

У root убран PruneLast=true: эта настройка переносит все prune-задачи в одну
последнюю волну и теряет порядок между удаляемыми Applications. Поэтому одного
добавления sync-wave при сохранении PruneLast здесь было бы недостаточно.

Три исходных chart остаются, но root задаёт renderScope, чтобы каждый ресурс
имел одного владельца. Общие secrets/RBAC/namespaces живут в базовых Applications.
Подробная таблица waves: [root README](../root/README.md).

## Destroy

Terraform сначала удаляет bootstrap release с root Application.
Argo сам обрабатывает каскадный finalizer и обратный порядок waves.
Terraform ждёт до 1200 секунд на bootstrap release, затем удаляет Argo.
Отдельный Terraform root удаляет k3d последним. Собственного цикла kubectl delete
и принудительного снятия finalizers нет.

Bootstrap AppProject и Secrets с настройками доступа сохраняются через
helm.sh/resource-policy: keep, чтобы Helm не удалил их раньше дочерних ресурсов.
Platform-only destroy оставляет эти объекты; полное удаление k3d удаляет и их.

Проблемный finalizer по-прежнему способен остановить удаление. Это защита от
преждевременного удаления зависимостей, не основание автоматически снимать его.
После устранения причины повторите destroy. При timeout Argo должен оставаться
работать. Terraform state нужен до завершения удаления.

## Проверка на временном кластере

1. Коммит/push новых правок; make github-runner-start.
2. Bootstrap apply. Перед следующей job перезапустите ephemeral runner при необходимости.
3. Deploy: postgres=enable, redis=enable, rabbitmq_stack=enable,
   payment_service=enable. Остальное keep.
4. Повторите выбор: конфигурационного коммита быть не должно.
5. Deploy rabbitmq_stack=disable: ровно один коммит; следите за Applications:
   topology исчезает раньше broker, затем operator и cert-manager.
6. Убедитесь, что payment-service и Redis остались.
7. Для проверки ошибки на disposable-кластере можно отдельно остановить topology
   controller перед disable: оператор/брокер не должны удалиться раньше CR.
   После теста восстановите контроллер. Это ручной fault-test, не штатный шаг.
8. Bootstrap destroy: дождитесь завершения, затем проверьте k3d cluster list
   и docker ps. Namespace не должен зависать из-за заранее удалённого оператора.

```bash
kubectl get applications -n argocd -w
ruby infra/github-actions/test-selection.rb
ruby infra/github-actions/test-gitops.rb
YQ_BIN=/path/to/yq ruby infra/github-actions/test-apply-selection.rb
```

Offline-тесты используют реальные Helm/jq/yq и временный Git-репозиторий.
Kubernetes и push/pull подменены: эти тесты не подтверждают поведение работающего
контроллера и не заменяют проверку apply/disable/destroy выше.
