resource "aws_budgets_budget" "cost_warning" {
    name                = "budget-cloud1-0.01-USD"
    budget_type         = "COST"
    limit_amount        = "0.01"
    limit_unit          = "USD"
    time_period_start   = "2025-01-01_00:00"
    time_unit           = "MONTHLY"

    notification {
        comparison_operator         = "GREATER_THAN"
        threshold                   = 100
        threshold_type              = "PERCENTAGE"
        notification_type           = "ACTUAL"
        subscriber_email_addresses  = ["pintusalessandropro@gmail.com"]
    }
}