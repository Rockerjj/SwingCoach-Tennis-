# Paid Advertising Playbook — $500-$1,000/month

## Budget Allocation

| Channel | % of Budget | Monthly Spend | Why |
|---------|------------|---------------|-----|
| Apple Search Ads | 50% | $250-500 | Highest intent — users are already searching the App Store |
| Meta (Instagram/Facebook) | 30% | $150-300 | Visual format matches our content, tennis audience targetable |
| TikTok | 20% | $100-200 | Lowest CPM, UGC-style ads perform well, young tennis players |

---

## Channel 1: Apple Search Ads

### Account Setup
1. Go to searchads.apple.com
2. Create account with your Apple ID
3. Link your app (com.tenniscoachai.app)
4. Set up conversion tracking (install + subscription events)

### Campaign Structure

**Campaign 1: Brand + Category (40% of ASA budget)**
```
Campaign: ASA_Category_Tennis
├── Ad Group 1: High Intent
│   Keywords: "tennis coach app", "tennis analysis app", 
│   "ai tennis coach", "tennis training app", "tennis form analyzer"
│   Match Type: Exact Match
│   Max CPT Bid: $2.00
│
├── Ad Group 2: Medium Intent  
│   Keywords: "tennis app", "tennis improvement", "tennis lessons app",
│   "tennis practice", "tennis technique"
│   Match Type: Exact Match
│   Max CPT Bid: $1.50
│
└── Ad Group 3: Broad Discovery
    Keywords: "tennis", "tennis training", "tennis coach"
    Match Type: Broad Match
    Max CPT Bid: $1.00
```

**Campaign 2: Competitor (20% of ASA budget)**
```
Campaign: ASA_Competitor
├── Ad Group: Competitor Names
│   Keywords: [names of competing tennis apps]
│   Match Type: Exact Match
│   Max CPT Bid: $1.50
```

**Campaign 3: Search Match (40% of ASA budget)**
```
Campaign: ASA_Discovery
├── Ad Group: Auto
│   Search Match: ON
│   Max CPT Bid: $1.00
│   (Apple automatically matches your app to relevant searches)
```

### Optimization Schedule
- **Week 1**: Launch all 3 campaigns with above structure
- **Week 2**: Review Search Term report. Move winning terms from Search Match to exact match campaigns. Add irrelevant terms as negatives.
- **Week 3**: Adjust bids based on CPI data. Increase bids on keywords with CPI < $2, decrease on > $4.
- **Week 4**: Calculate cost-per-subscriber (not just CPI). Shift budget to campaigns that produce actual subscribers.

### Key Metrics
| Metric | Target |
|--------|--------|
| Tap-Through Rate (TTR) | 8%+ |
| Conversion Rate (CR) | 50%+ |
| Cost Per Install (CPI) | < $2.50 |
| Cost Per Subscriber | < $25 |

---

## Channel 2: Meta Ads (Instagram/Facebook)

### Account Setup
1. Create a Meta Business account (business.facebook.com)
2. Set up the app in Meta for Developers
3. Install Facebook SDK or use the App Events API
4. Set up app install campaign

### Campaign Structure

**Campaign: App Installs — Tennis Players**
```
Campaign: META_AppInstall_Tennis
Objective: App Installs
Optimization: App Installs (switch to App Events/Purchase after 50+ events)

├── Ad Set 1: Tennis Interest Targeting
│   Audience:
│   - Age: 18-45
│   - Location: US, UK, Australia, Canada
│   - Interests: Tennis, USTA, ATP Tour, WTA, Tennis Channel,
│     Wilson Tennis, Head Tennis, Babolat, Roger Federer,
│     Rafael Nadal, Novak Djokovic, Tennis Warehouse
│   - Exclude: Existing app users
│   
│   Placements: Instagram Reels, Instagram Feed, Facebook Reels
│   Budget: $5-10/day
│
├── Ad Set 2: Fitness + Sports Broad
│   Audience:
│   - Age: 25-45
│   - Location: US
│   - Interests: Fitness apps, Sports analytics, Athletic training
│   - Narrow further: Tennis OR Racket sports
│   
│   Budget: $3-5/day
│
└── Ad Set 3: Lookalike (after 100+ installs)
    Audience:
    - Lookalike of app installers (1%)
    - Location: US
    
    Budget: $5-10/day
```

### Ad Creative (3 variations to test)

**Creative 1: "Watch AI Analyze This" (Demo)**
```
Format: Vertical Video (9:16), 15-20 seconds
Hook (0-3s): Text overlay "I let AI analyze my forehand..."
Body (3-15s): Show hitting stroke -> cut to skeleton overlay -> show grade
CTA (15-20s): "Download Tennis Coach AI — Free"
```

**Creative 2: "Before vs After" (Transformation)**
```
Format: Vertical Video (9:16), 15-20 seconds
Hook (0-3s): "Day 1 vs Day 30 with AI coaching"
Body (3-15s): Split screen before/after with grades improving
CTA (15-20s): "Start improving today — Download free"
```

**Creative 3: "Your Coach Can't See This" (Problem-Solve)**
```
Format: Static Image or Carousel
Image: Skeleton overlay screenshot from the app
Headline: "See what your tennis coach can't see"
Primary Text: "AI analyzes every angle of your swing — backswing, 
contact point, follow-through. Get graded and coached on every stroke."
CTA Button: "Install Now"
```

### Optimization Rules
- Kill any ad with CPI > $4 after $20 spent
- Scale ads with CPI < $2 by increasing budget 20%
- Refresh creative every 2 weeks (ad fatigue)
- Move best organic Reels into the ad rotation
- After 50+ installs, switch optimization to "App Events" targeting subscription events

---

## Channel 3: TikTok Ads

### Account Setup
1. Create TikTok Ads Manager account (ads.tiktok.com)
2. Set up TikTok Pixel or Events API
3. Connect your app for tracking

### Campaign Structure

**Primary Approach: Spark Ads**
Spark Ads let you boost your existing organic TikTok posts as ads. This is the most effective format because it preserves the native feel.

```
Campaign: TT_SparkAds_Tennis
Objective: App Install

├── Ad Group 1: Tennis Interest
│   Audience:
│   - Age: 18-35
│   - Location: US, UK, Australia
│   - Interests: Tennis, Racket Sports, Sports Training
│   - Behaviors: Sports App Users
│   
│   Spark Ads: Boost top 2-3 organic posts
│   Budget: $3-7/day
│
└── Ad Group 2: Broad (let algorithm find audience)
    Audience:
    - Age: 18-45
    - Location: US
    - No interest targeting (let TikTok optimize)
    
    Spark Ads: Same top organic posts
    Budget: $3-5/day
```

### Creative Guidelines for TikTok
- **Native feel is mandatory** — polished ads underperform
- **First 2 seconds hook** — "POV: AI watches you play tennis"
- **Show the app UI** — the skeleton overlay IS the hook
- **Trending audio** — use popular tennis or sports sounds
- **Captions on screen** — most watch muted
- **CTA**: "Link in bio" or TikTok's built-in app install button

---

## Monthly Optimization Calendar

### Week 1: Launch
- [ ] Launch all 3 channels with initial campaigns
- [ ] Set up conversion tracking on all platforms
- [ ] 2-3 ad creatives per channel
- [ ] Daily budget check (don't overspend)

### Week 2: First Optimization
- [ ] Review Apple Search Ads search terms (move winners, add negatives)
- [ ] Kill underperforming Meta ads (CPI > $4)
- [ ] Check TikTok Spark Ads performance
- [ ] Calculate blended CPI across all channels

### Week 3: Creative Refresh
- [ ] Create 2-3 new ad creatives from latest organic content
- [ ] Test new headlines on Meta
- [ ] Boost new organic TikTok posts as Spark Ads
- [ ] Adjust ASA bids based on 2-week data

### Week 4: Budget Reallocation
- [ ] Calculate cost-per-subscriber for each channel
- [ ] Shift budget from lowest-performing to highest-performing channel
- [ ] Review total spend vs. revenue generated
- [ ] Plan next month's creative and budget

---

## Key Principle: Optimize for Subscribers, Not Installs

An install that never subscribes costs you money (API costs for free analyses). Track these metrics:

| Metric | How to Calculate | Target |
|--------|-----------------|--------|
| CPI | Total spend / installs | < $2.50 |
| Cost Per Subscriber | Total spend / new paid subscribers | < $25 |
| ROAS | Subscriber revenue / ad spend | > 2x within 30 days |
| Blended CAC | Total marketing spend / total new subscribers | < $30 |

If a channel has low CPI but high cost-per-subscriber, it's bringing the wrong users. Shift budget to the channel with the lowest cost-per-subscriber, even if the CPI is higher.

---

## Scaling Rules

Once you find a winning channel + creative combination:
1. Increase budget by 20% every 5 days (not all at once)
2. Don't change targeting and creative simultaneously
3. Let campaigns run for 72 hours after changes before judging
4. At $1,000+/month, consider hiring a freelance media buyer ($500-1000/month)

## When to Increase Budget
- If cost-per-subscriber < $20 consistently for 2+ weeks
- If you have more demand than your content calendar can serve
- If organic growth is also increasing (ads + organic compound)
